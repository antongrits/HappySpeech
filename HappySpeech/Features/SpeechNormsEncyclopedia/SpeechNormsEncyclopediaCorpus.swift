import Foundation
import OSLog

// MARK: - SpeechNormsEncyclopediaCorpus
//
// v31 Волна A, Функция Ф10 «Что должно быть в возрасте».
//
// Корпус карточек возрастных норм речевого развития, загруженных из
// бандл-пака `pack_speech_norms.json`. ~36 карточек: 4 возраста × 5 осей
// + ~12 красных флагов + обзорные карточки.
//
// Полностью offline / on-device.

enum SpeechNormsEncyclopediaCorpus {

    /// Все карточки энциклопедии.
    static let cards: [NormCard] = SpeechNormsPackLoader.shared.cards

    /// Этическая сноска — статичная для всего экрана.
    static var ethicsNote: String { SpeechNormsPackLoader.shared.ethics }

    /// Карточки для конкретного возраста.
    static func cards(for age: NormAge) -> [NormCard] {
        cards.filter { $0.age == age }
    }

    /// Поиск по подстроке в заголовке, summary и body.
    static func filter(by query: String, in cards: [NormCard]) -> [NormCard] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return cards }
        return cards.filter { card in
            card.title.lowercased().contains(trimmed)
                || card.summary.lowercased().contains(trimmed)
                || card.body.lowercased().contains(trimmed)
        }
    }
}

// MARK: - SpeechNormsPackLoader
//
// Разбирает `pack_speech_norms.json` один раз. При отказе бандла — fallback.

struct SpeechNormsPackLoader {

    static let shared = SpeechNormsPackLoader()

    let cards: [NormCard]
    let ethics: String

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpeechNorms.PackLoader"
    )

    private struct Pack: Decodable {
        let schemaVersion: Int
        let packId: String
        let ethics: String?
        let cards: [CardDTO]
    }

    private struct CardDTO: Decodable {
        let id: String
        let age: Int
        let axis: String
        let title: String
        let summary: String
        let body: String
        let sources: [String]
    }

    private init() {
        guard let url = Bundle.main.url(
            forResource: "pack_speech_norms", withExtension: "json"
        ) else {
            Self.logger.error("pack_speech_norms.json not found in bundle — using fallback")
            cards = SpeechNormsPackLoader.fallbackCards
            ethics = SpeechNormsPackLoader.fallbackEthics
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            ethics = pack.ethics ?? SpeechNormsPackLoader.fallbackEthics
            cards = pack.cards.compactMap { dto in
                guard let age = NormAge(rawValue: dto.age) else {
                    Self.logger.error("Unknown age in card: \(dto.id, privacy: .public)")
                    return nil
                }
                guard let axis = NormAxis(rawValue: dto.axis) else {
                    Self.logger.error("Unknown axis in card: \(dto.id, privacy: .public)")
                    return nil
                }
                return NormCard(
                    id: dto.id,
                    age: age,
                    axis: axis,
                    title: dto.title,
                    summary: dto.summary,
                    body: dto.body,
                    sources: dto.sources
                )
            }
        } catch {
            Self.logger.error(
                "pack_speech_norms.json decode error: \(error.localizedDescription, privacy: .public)"
            )
            cards = SpeechNormsPackLoader.fallbackCards
            ethics = SpeechNormsPackLoader.fallbackEthics
        }
    }

    private static let fallbackEthics = """
    Карточки содержат педагогически-просветительский материал. Каждый ребёнок \
    развивается индивидуально. При сомнениях — обратитесь к логопеду.
    """

    /// Безопасный минимум на случай отказа бандла.
    private static let fallbackCards: [NormCard] = [
        NormCard(
            id: "norm-fallback-5",
            age: .five,
            axis: .sounds,
            title: "Звуки в 5 лет",
            summary: "К 5 годам обычно усвоены все звуки, кроме Р и иногда шипящих.",
            body: """
            В норме к 5 годам сформированы свистящие, шипящие и заднеязычные \
            звуки. Звук Р может ещё ставиться — это самый поздний звук русского \
            языка.
            """,
            sources: ["Гвоздев А.Н., 1961"]
        ),
        NormCard(
            id: "norm-fallback-6",
            age: .six,
            axis: .sounds,
            title: "Звуки в 6 лет",
            summary: "Все звуки должны быть в норме.",
            body: """
            К 6 годам все звуки русского языка сформированы. Если Р или шипящие \
            искажаются — это нарушение, требующее коррекции.
            """,
            sources: ["Фомичёва М.Ф., 1989"]
        ),
        NormCard(
            id: "norm-fallback-7",
            age: .seven,
            axis: .sounds,
            title: "Звуки перед школой",
            summary: "Звукопроизношение должно быть полностью сформированным.",
            body: """
            К 7 годам — началу школы — все звуки должны быть чистыми. Иначе это \
            приведёт к специфическим ошибкам в письме.
            """,
            sources: ["Каше Г.А., 1985"]
        ),
        NormCard(
            id: "norm-fallback-8",
            age: .eight,
            axis: .motor,
            title: "Письменная речь в 8 лет",
            summary: "Освоение прописных букв, грамотное письмо.",
            body: """
            К концу 1 класса ребёнок пишет без специфических ошибок. Стойкие \
            пропуски и замены букв — признак дисграфии.
            """,
            sources: ["Лалаева Р.И., 2002"]
        )
    ]
}
