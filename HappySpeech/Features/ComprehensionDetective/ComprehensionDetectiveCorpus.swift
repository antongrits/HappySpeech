import Foundation
import OSLog

// MARK: - ComprehensionDetectiveCorpus
//
// v31 Волна B, Функция Ф.2 «Понимание-детектив» (F2-014).
//
// Загрузчик корпуса инструкций для импрессивной речи из bundled JSON
// `Content/Seed/pack_impressive_speech.json`. ≥120 пунктов на 5 уровней
// грамматической сложности (Левина). Каждый пункт несёт возрастной гейт
// (`minAge`). Полностью offline / on-device.

public enum ComprehensionDetectiveCorpus {

    /// Сколько раундов в одной сессии (антифатиговое правило, 6–12).
    public static var roundsPerSession: Int { loader.roundsPerSession }

    public static var allItems: [DetectiveItem] { loader.items }

    /// Пункты заданного уровня.
    public static func items(for tier: GrammarTier) -> [DetectiveItem] {
        allItems.filter { $0.tier == tier }
    }

    /// Пункты уровня, допустимые для возраста (minAge ≤ age).
    public static func items(for tier: GrammarTier, maxAge age: Int) -> [DetectiveItem] {
        items(for: tier).filter { $0.minAge <= age }
    }

    /// Уровни, у которых есть хотя бы один пункт.
    public static var availableTiers: [GrammarTier] {
        let present = Set(allItems.map(\.tier))
        return GrammarTier.allCases.filter { present.contains($0) }
    }

    /// Уровни, доступные для возраста (есть подходящие по minAge пункты).
    public static func availableTiers(maxAge age: Int) -> [GrammarTier] {
        GrammarTier.allCases.filter { !items(for: $0, maxAge: age).isEmpty }
    }

    // MARK: - Private

    private static let loader = ComprehensionDetectivePackLoader.shared
}

// MARK: - ComprehensionDetectivePackLoader
//
// Разбирает `pack_impressive_speech.json` один раз. При отказе бандла
// возвращает безопасный минимальный набор, чтобы модуль оставался рабочим.

struct ComprehensionDetectivePackLoader {

    static let shared = ComprehensionDetectivePackLoader()

    let roundsPerSession: Int
    let items: [DetectiveItem]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ComprehensionDetective.PackLoader"
    )

    private init() {
        guard let url = Bundle.main.url(
            forResource: "pack_impressive_speech", withExtension: "json"
        ) else {
            Self.logger.error("pack_impressive_speech.json not found — using fallback")
            roundsPerSession = 9
            items = Self.fallbackItems
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(PackDTO.self, from: data)
            roundsPerSession = max(6, pack.roundsPerSession ?? 9)
            let decoded = pack.tiers.flatMap { tierDTO -> [DetectiveItem] in
                guard let tier = GrammarTier(rawValue: tierDTO.tier) else {
                    Self.logger.error("Unknown tier: \(tierDTO.tier, privacy: .public)")
                    return []
                }
                return tierDTO.items.compactMap { Self.makeItem($0, tier: tier) }
            }
            let resolved = decoded.isEmpty ? Self.fallbackItems : decoded
            items = resolved
            Self.logger.info("DetectiveCorpus loaded: \(resolved.count, privacy: .public) items")
        } catch {
            Self.logger.error(
                "pack_impressive_speech.json decode error: \(error.localizedDescription, privacy: .public)"
            )
            roundsPerSession = 9
            items = Self.fallbackItems
        }
    }

    private static func makeItem(_ dto: ItemDTO, tier: GrammarTier) -> DetectiveItem? {
        // Картинки: первая — правильная (correct), затем distractor'ы.
        let allSymbols = [dto.correct] + dto.distractors
        let pictures = allSymbols.map { symbol -> DetectivePicture in
            let label = dto.labels[symbol] ?? symbol
            return DetectivePicture(
                id: "\(dto.id)-\(symbol)",
                symbolName: symbol,
                label: label
            )
        }
        guard let correctPicture = pictures.first else { return nil }
        return DetectiveItem(
            id: dto.id,
            tier: tier,
            instruction: dto.instruction,
            pictures: pictures,
            correctPictureId: correctPicture.id,
            minAge: dto.minAge ?? tier.minAge
        )
    }

    // MARK: - JSON DTOs

    private struct PackDTO: Decodable {
        let roundsPerSession: Int?
        let tiers: [TierDTO]
    }

    private struct TierDTO: Decodable {
        let tier: Int
        let items: [ItemDTO]
    }

    private struct ItemDTO: Decodable {
        let id: String
        let minAge: Int?
        let instruction: String
        let correct: String
        let distractors: [String]
        let labels: [String: String]
    }

    // MARK: - Fallback (минимальный рабочий набор)

    private static let fallbackItems: [DetectiveItem] = [
        makeFallback(id: "fb-myach", tier: .simple, minAge: 5,
                     instruction: "Покажи мяч",
                     correct: ("soccerball", "мяч"),
                     distractors: [("car.fill", "машина"), ("leaf.fill", "лист"), ("house.fill", "дом")]),
        makeFallback(id: "fb-koshka", tier: .simple, minAge: 5,
                     instruction: "Покажи кошку",
                     correct: ("cat.fill", "кошка"),
                     distractors: [("bird.fill", "птица"), ("fish.fill", "рыба"), ("ant.fill", "муравей")]),
        makeFallback(id: "fb-sun-moon", tier: .doubleInstruction, minAge: 5,
                     instruction: "Найди солнце, а потом луну",
                     correct: ("sun.max.fill", "солнце"),
                     distractors: [("moon.fill", "луна"), ("star.fill", "звезда"), ("cloud.fill", "облако")]),
        makeFallback(id: "fb-na-stole", tier: .withPreposition, minAge: 5,
                     instruction: "Покажи, где книга лежит на столе",
                     correct: ("books.vertical.fill", "книга на столе"),
                     distractors: [("table.furniture.fill", "пустой стол"), ("book.fill", "книга в руке"), ("chair.fill", "стул")]),
        makeFallback(id: "fb-chem-risuyut", tier: .logicalGrammatical, minAge: 6,
                     instruction: "Покажи то, чем рисуют",
                     correct: ("paintbrush.fill", "кисть"),
                     distractors: [("scissors", "ножницы"), ("fork.knife", "вилка"), ("key.fill", "ключ")])
    ]

    private static func makeFallback(
        id: String,
        tier: GrammarTier,
        minAge: Int,
        instruction: String,
        correct: (String, String),
        distractors: [(String, String)]
    ) -> DetectiveItem {
        let all = [correct] + distractors
        let pictures = all.map { DetectivePicture(id: "\(id)-\($0.0)", symbolName: $0.0, label: $0.1) }
        return DetectiveItem(
            id: id, tier: tier, instruction: instruction,
            pictures: pictures, correctPictureId: pictures[0].id, minAge: minAge
        )
    }
}
