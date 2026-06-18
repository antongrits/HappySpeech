import Foundation
import OSLog

// MARK: - StoryPicturesBuilder
//
// Worker «Рассказа по серии картинок». Чистая методическая логика (тестируема):
//   1. Загрузка пака `pack_picture_series.json` → `[PictureSeries]`.
//   2. Подбор серии по возрасту (число кадров растёт с возрастом).
//   3. Детерминированное перемешивание кадров для drag-упорядочивания.
//   4. Проверка верности собранного порядка.
//   5. Семантический матчинг: какие смысловые звенья названы в ASR-транскрипте.
//   6. Расчёт арки полноты рассказа (завязка / действие / развязка).
//
// Семантика по Глухову/Ткаченко: важна ПОЛНОТА высказывания (названы ли
// смысловые звенья), а не «правильность» — поэтому матчинг по корням-ключам,
// устойчивый к искажённой детской речи и словоформам.

@MainActor
final class StoryPicturesBuilder {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "StoryPicturesBuilder")

    // MARK: - Возрастные пороги (число кадров серии)

    /// 5–6 → 2–3 кадра, 6–7 → 4 кадра, 7–8 → 5–6 кадров (Ткаченко).
    static func maxFrames(forAge age: Int) -> Int {
        switch age {
        case ..<6:  return 3
        case 6:     return 4
        default:    return 6
        }
    }

    // MARK: - Pack loading

    /// Загружает все серии из пака; при отсутствии/повреждении — встроенный
    /// fallback (тоже реальная серия), чтобы экран никогда не был пустым.
    func loadSeries() -> [PictureSeries] {
        guard let raw = Self.loadPack() else {
            logger.warning("pack_picture_series.json missing — using built-in fallback series")
            return [Self.fallbackSeries()]
        }
        let series = raw.series.compactMap { Self.makeSeries(from: $0) }
        guard !series.isEmpty else {
            logger.warning("pack_picture_series.json produced 0 series — using fallback")
            return [Self.fallbackSeries()]
        }
        logger.info("loaded \(series.count, privacy: .public) picture series")
        return series
    }

    /// Выбирает серию под возраст: предпочитает серии, чей диапазон включает
    /// возраст и чьё число кадров не превышает возрастной максимум; иначе —
    /// серию с наибольшим подходящим числом кадров.
    func pickSeries(from all: [PictureSeries], age: Int) -> PictureSeries? {
        guard !all.isEmpty else { return nil }
        let limit = Self.maxFrames(forAge: age)
        let eligible = all.filter { $0.frames.count <= limit }
        let pool = eligible.isEmpty ? all : eligible
        // Среди подходящих — та, чей возрастной диапазон ближе к ребёнку.
        let inRange = pool.filter { age >= $0.minAge && age <= $0.maxAge }
        let candidates = inRange.isEmpty ? pool : inRange
        // Берём серию с максимальным числом кадров в рамках лимита (сложнее).
        return candidates.max { $0.frames.count < $1.frames.count }
    }

    // MARK: - Shuffle (детерминированный для тестов через seed)

    /// Перемешивает кадры так, чтобы исходный правильный порядок не сохранялся.
    /// Для детерминизма (тесты/seed) — линейный конгруэнтный генератор.
    func shuffledFrameIds(for series: PictureSeries, seed: UInt64? = nil) -> [String] {
        let ordered = series.orderedFrames.map { $0.id }
        guard ordered.count > 1 else { return ordered }
        var rng = SeededGenerator(seed: seed ?? UInt64.random(in: 1...UInt64.max))
        var shuffled = ordered
        var attempts = 0
        repeat {
            shuffled.shuffle(using: &rng)
            attempts += 1
        } while shuffled == ordered && attempts < 8
        return shuffled
    }

    // MARK: - Order validation

    /// Верен ли собранный порядок: каждый кадр стоит на своей позиции (1-based
    /// `order` совпадает с индексом слота + 1).
    func isOrderCorrect(placedFrameIds: [String?], series: PictureSeries) -> Bool {
        let frames = series.frames
        guard placedFrameIds.count == frames.count,
              placedFrameIds.allSatisfy({ $0 != nil }) else { return false }
        for (slotIndex, frameId) in placedFrameIds.enumerated() {
            guard let frameId,
                  let frame = frames.first(where: { $0.id == frameId }) else { return false }
            if frame.order != slotIndex + 1 { return false }
        }
        return true
    }

    /// Индекс первого пустого слота (для подсветки «next»); nil если заполнено.
    func nextEmptySlot(in placed: [String?]) -> Int? {
        placed.firstIndex(where: { $0 == nil })
    }

    // MARK: - Semantic link matching (ASR)

    /// Возвращает id звеньев, чьи ключевые корни найдены в транскрипте.
    /// Матчинг по нормализованным корням (lowercased, ё→е), устойчив к
    /// словоформам и искажённой детской речи.
    func coveredLinks(in transcript: String, links: [StoryLink]) -> Set<String> {
        let normalized = Self.normalize(transcript)
        guard !normalized.isEmpty else { return [] }
        var covered: Set<String> = []
        for link in links {
            let hit = link.keywords.contains { keyword in
                let key = Self.normalize(keyword)
                return !key.isEmpty && normalized.contains(key)
            }
            if hit { covered.insert(link.id) }
        }
        return covered
    }

    /// Нормализация для матчинга: lowercase, ё→е, оставить буквы/пробелы.
    static func normalize(_ text: String) -> String {
        let lowered = text.lowercased().replacingOccurrences(of: "ё", with: "е")
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.letters.contains(scalar) { return Character(scalar) }
            return " "
        }
        return String(scalars)
    }

    // MARK: - Story arc

    /// Считает покрытие арки по ролям для серии и множества названных звеньев.
    func computeArc(series: PictureSeries, coveredLinkIds: Set<String>) -> StoryArc {
        var coverage: [StoryLinkRole: Double] = [:]
        for role in StoryLinkRole.allCases {
            let roleLinks = series.frames.flatMap { $0.links }.filter { $0.role == role }
            guard !roleLinks.isEmpty else { continue }   // роль не представлена в серии
            let named = roleLinks.filter { coveredLinkIds.contains($0.id) }.count
            coverage[role] = Double(named) / Double(roleLinks.count)
        }
        return StoryArc(coverageByRole: coverage)
    }

    /// Краткая сводка ответов-подсказок по роли (для подписи сегмента арки).
    func summary(for role: StoryLinkRole, in series: PictureSeries) -> String {
        let hints = series.frames
            .flatMap { $0.links }
            .filter { $0.role == role }
            .map { $0.answerHint }
        var seen = Set<String>()
        let unique = hints.filter { seen.insert($0).inserted }
        return unique.prefix(2).joined(separator: ", ")
    }

    // MARK: - Pure: mapping pack → domain

    private static func makeSeries(from rs: RawSeries) -> PictureSeries? {
        guard !rs.frames.isEmpty, !rs.id.isEmpty else { return nil }
        let frames = rs.frames.compactMap(makeFrame)
        guard !frames.isEmpty else { return nil }
        return PictureSeries(
            id: rs.id,
            title: rs.title,
            minAge: rs.minAge,
            maxAge: rs.maxAge,
            scene: StoryPictureScene(rawValue: rs.scene) ?? .generic,
            frames: frames
        )
    }

    private static func makeFrame(from rf: RawFrame) -> PictureFrame? {
        guard !rf.id.isEmpty else { return nil }
        let links = rf.links.map { rl in
            StoryLink(
                id: rl.id,
                role: StoryLinkRole(rawValue: rl.role) ?? .action,
                question: rl.question,
                answerHint: rl.answerHint,
                keywords: rl.keywords.map { $0.lowercased() }
            )
        }
        return PictureFrame(
            id: rf.id,
            order: max(1, rf.order),
            scene: StoryPictureScene(rawValue: rf.scene) ?? .generic,
            caption: rf.caption,
            imageAsset: rf.imageAsset,
            links: links
        )
    }

    // MARK: - Pack DTOs

    private struct RawPack: Decodable {
        let series: [RawSeries]
    }
    private struct RawSeries: Decodable {
        let id: String
        let title: String
        let minAge: Int
        let maxAge: Int
        let scene: String
        let frames: [RawFrame]

        enum CodingKeys: String, CodingKey {
            case id, title, minAge, maxAge, scene, frames
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            title = (try? c.decode(String.self, forKey: .title)) ?? ""
            minAge = (try? c.decode(Int.self, forKey: .minAge)) ?? 5
            maxAge = (try? c.decode(Int.self, forKey: .maxAge)) ?? 8
            scene = (try? c.decode(String.self, forKey: .scene)) ?? "generic"
            frames = try c.decode([RawFrame].self, forKey: .frames)
        }
    }
    private struct RawFrame: Decodable {
        let id: String
        let order: Int
        let scene: String
        let caption: String
        let imageAsset: String?
        let links: [RawLink]

        enum CodingKeys: String, CodingKey {
            case id, order, scene, caption, imageAsset, links
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            order = (try? c.decode(Int.self, forKey: .order)) ?? 1
            scene = (try? c.decode(String.self, forKey: .scene)) ?? "generic"
            caption = (try? c.decode(String.self, forKey: .caption)) ?? ""
            imageAsset = try? c.decode(String.self, forKey: .imageAsset)
            links = (try? c.decode([RawLink].self, forKey: .links)) ?? []
        }
    }
    private struct RawLink: Decodable {
        let id: String
        let role: String
        let question: String
        let answerHint: String
        let keywords: [String]

        enum CodingKeys: String, CodingKey {
            case id, role, question, answerHint, keywords
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            role = (try? c.decode(String.self, forKey: .role)) ?? "action"
            question = (try? c.decode(String.self, forKey: .question)) ?? ""
            answerHint = (try? c.decode(String.self, forKey: .answerHint)) ?? ""
            keywords = (try? c.decode([String].self, forKey: .keywords)) ?? []
        }
    }

    // MARK: - Pack IO

    private static func loadPack() -> RawPack? {
        guard let url = Bundle.main.url(forResource: "pack_picture_series", withExtension: "json")
            ?? Bundle.main.url(
                forResource: "pack_picture_series",
                withExtension: "json",
                subdirectory: "Seed"
            ),
            let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(RawPack.self, from: data)
    }

    // MARK: - Fallback

    /// Встроенная серия «Ёжик и яблоко» — на случай отсутствия пака в бандле.
    /// COPPA-safe (животные, без людей). Никаких пустых экранов.
    static func fallbackSeries() -> PictureSeries {
        func link(_ id: String, _ role: StoryLinkRole, _ question: String, _ hint: String, _ kw: [String]) -> StoryLink {
            StoryLink(id: id, role: role, question: question, answerHint: hint, keywords: kw.map { $0.lowercased() })
        }
        return PictureSeries(
            id: "ps_hedgehog_apple",
            title: String(localized: "storyPictures.series.hedgehog", defaultValue: "Ёжик и яблоко"),
            minAge: 6, maxAge: 7, scene: .hedgehogSeesTree,
            frames: [
                PictureFrame(
                    id: "ps_hedgehog_apple_1", order: 1, scene: .hedgehogSeesTree,
                    caption: "Ёжик увидел яблоньку", imageAsset: nil,
                    links: [
                        link("setup", .setup, "Кто?", "ёжик", ["ёжик", "ежик", "ёж", "еж"]),
                        link("setup_obj", .setup, "Что увидел?", "яблоки", ["яблок", "яблоня", "дерево"])
                    ]
                ),
                PictureFrame(
                    id: "ps_hedgehog_apple_2", order: 2, scene: .hedgehogShakesTree,
                    caption: "Ёжик трясёт яблоньку", imageAsset: nil,
                    links: [
                        link("actor", .action, "Кто?", "ёжик", ["ёжик", "ежик", "ёж", "еж"]),
                        link("action", .action, "Что делает?", "трясёт", ["тряс", "качал", "тряхнул"]),
                        link("fell", .action, "Что упало?", "яблоки", ["упал", "яблок", "посыпал"])
                    ]
                ),
                PictureFrame(
                    id: "ps_hedgehog_apple_3", order: 3, scene: .hedgehogRollsApple,
                    caption: "Ёжик накалывает яблоко", imageAsset: nil,
                    links: [
                        link("actor2", .action, "Кто?", "ёжик", ["ёжик", "ежик", "ёж", "еж"]),
                        link("collect", .action, "Что сделал?", "наколол", ["накол", "собрал", "поднял", "взял"])
                    ]
                ),
                PictureFrame(
                    id: "ps_hedgehog_apple_4", order: 4, scene: .hedgehogCarriesHome,
                    caption: "Ёжик принёс яблоки домой", imageAsset: nil,
                    links: [
                        link("actor3", .resolution, "Кто?", "ёжик", ["ёжик", "ежик", "ёж", "еж"]),
                        link("carry", .resolution, "Что сделал?", "принёс", ["принёс", "принес", "понёс", "понес", "унёс", "унес"]),
                        link("where", .resolution, "Куда?", "домой", ["домой", "дом", "норку", "норка"])
                    ]
                )
            ]
        )
    }
}

// MARK: - Seeded RNG (детерминизм для тестов / shuffle)

/// Линейный конгруэнтный генератор (Numerical Recipes) — детерминированный
/// `RandomNumberGenerator` для воспроизводимого перемешивания в тестах.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Гарантируем ненулевое стартовое состояние.
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
