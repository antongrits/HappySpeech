import Foundation
import OSLog

// MARK: - LexicalThemesCorpus
//
// v29 Фаза 8, Функция 7 «Мир слов».
//
// Корпус лексических тем — 16 тем по ~40 слов (≈640 единиц). Каждое слово
// размечено существительным, типичным действием («что делает?») и признаком
// («какой?») — предметный, глагольный и признаковый словарь (Филичёва,
// Чиркина: коррекция ОНР по лексическим темам).
//
// Контент загружается из бандл-ресурса `pack_lexical_themes.json`.
// Полностью offline / on-device.

enum LexicalThemesCorpus {

    /// Сколько раундов в одной сессии темы (8–12 мин, антифатиговое правило).
    static let roundsPerSession = LexicalThemesPackLoader.shared.roundsPerSession

    /// Все лексические темы (из `pack_lexical_themes.json`).
    static let themes: [LexicalTheme] = LexicalThemesPackLoader.shared.themes

    /// Все слова всех тем — для построения дистракторов.
    static var allWords: [LexicalWord] {
        themes.flatMap(\.words)
    }

    /// Тема по идентификатору.
    static func theme(id: String) -> LexicalTheme? {
        themes.first { $0.id == id }
    }

    /// Слова других тем (дистракторы для «четвёртого лишнего» и обобщения).
    static func words(excludingTheme themeId: String) -> [LexicalWord] {
        themes.filter { $0.id != themeId }.flatMap(\.words)
    }

    /// Обобщающие понятия всех тем (дистракторы для игры «обобщение»).
    static var allGeneralizations: [String] {
        themes.map(\.generalization)
    }
}

// MARK: - LexicalThemesPackLoader
//
// Разбирает `pack_lexical_themes.json` один раз. При отказе бандла возвращает
// безопасный минимальный набор, чтобы модуль оставался рабочим.

struct LexicalThemesPackLoader {

    static let shared = LexicalThemesPackLoader()

    let roundsPerSession: Int
    let themes: [LexicalTheme]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "LexicalThemes.PackLoader"
    )

    private struct Pack: Decodable {
        let roundsPerSession: Int
        let themes: [ThemeDTO]
    }

    private struct ThemeDTO: Decodable {
        let id: String
        let title: String
        let generalization: String
        let symbolName: String
        let words: [WordDTO]
    }

    private struct WordDTO: Decodable {
        let id: String
        let text: String
        let action: String
        let attribute: String
    }

    private init() {
        guard let url = Bundle.main.url(
            forResource: "pack_lexical_themes", withExtension: "json"
        ) else {
            Self.logger.error("pack_lexical_themes.json not found in bundle — using fallback")
            roundsPerSession = 8
            themes = LexicalThemesPackLoader.fallbackThemes
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            roundsPerSession = pack.roundsPerSession
            themes = pack.themes.map { dto in
                LexicalTheme(
                    id: dto.id,
                    title: dto.title,
                    generalization: dto.generalization,
                    symbolName: dto.symbolName,
                    words: dto.words.map { word in
                        LexicalWord(
                            id: word.id,
                            text: word.text,
                            action: word.action,
                            attribute: word.attribute
                        )
                    }
                )
            }
        } catch {
            Self.logger.error(
                "pack_lexical_themes.json decode error: \(error.localizedDescription, privacy: .public)"
            )
            roundsPerSession = 8
            themes = LexicalThemesPackLoader.fallbackThemes
        }
    }

    /// Минимальный безопасный набор на случай отказа бандла.
    private static let fallbackThemes: [LexicalTheme] = [
        LexicalTheme(
            id: "vegetables", title: "Овощи", generalization: "овощи",
            symbolName: "carrot.fill",
            words: [
                .init(id: "veg-1", text: "морковь", action: "растёт", attribute: "оранжевая"),
                .init(id: "veg-2", text: "капуста", action: "хрустит", attribute: "хрустящая"),
                .init(id: "veg-3", text: "помидор", action: "краснеет", attribute: "красный"),
                .init(id: "veg-4", text: "огурец", action: "зеленеет", attribute: "зелёный"),
                .init(id: "veg-5", text: "картофель", action: "варится", attribute: "рассыпчатый"),
                .init(id: "veg-6", text: "лук", action: "горчит", attribute: "горький"),
                .init(id: "veg-7", text: "свёкла", action: "зреет", attribute: "бордовая"),
                .init(id: "veg-8", text: "тыква", action: "наливается", attribute: "большая")
            ]
        ),
        LexicalTheme(
            id: "fruits", title: "Фрукты", generalization: "фрукты",
            symbolName: "applelogo",
            words: [
                .init(id: "fru-1", text: "яблоко", action: "падает", attribute: "сочное"),
                .init(id: "fru-2", text: "груша", action: "висит", attribute: "сладкая"),
                .init(id: "fru-3", text: "банан", action: "желтеет", attribute: "жёлтый"),
                .init(id: "fru-4", text: "апельсин", action: "пахнет", attribute: "ароматный"),
                .init(id: "fru-5", text: "слива", action: "зреет", attribute: "синяя"),
                .init(id: "fru-6", text: "лимон", action: "кислит", attribute: "кислый"),
                .init(id: "fru-7", text: "виноград", action: "наливается", attribute: "сладкий"),
                .init(id: "fru-8", text: "вишня", action: "краснеет", attribute: "красная")
            ]
        )
    ]
}
