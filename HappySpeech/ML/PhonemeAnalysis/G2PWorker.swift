import Foundation
import OSLog

// MARK: - G2PWorker

/// Конвертер grapheme-to-phoneme для русского языка.
///
/// Загружает `russian_phonemes.json` (7712 записей) из Bundle при инициализации.
/// При отсутствии слова в словаре применяет правиловой fallback.
///
/// **Правила fallback (упрощённая G2P для русского):**
/// - Базовая транслитерация кириллица → IPA
/// - Палатализация перед е/ё/и/ю/я
/// - Оглушение в конце слова
/// - Йотированные гласные в начале/после гласной
///
/// ## See Also
/// - ``PhonemeAnalysisService``
public actor G2PWorker {

    private let logger = Logger(subsystem: "HappySpeech", category: "G2PWorker")

    /// Словарь: русское слово → массив IPA фонем.
    private var dictionary: [String: [String]] = [:]

    // MARK: - Init

    /// Инициализирует G2PWorker, загружая словарь из Bundle.
    /// - Throws: ``G2PError/dictionaryNotFound`` если JSON не найден
    public init() throws {
        guard let url = Bundle.main.url(
            forResource: "russian_phonemes",
            withExtension: "json",
            subdirectory: "G2P"
        ) else {
            throw G2PError.dictionaryNotFound
        }

        let data = try Data(contentsOf: url)
        let json = try JSONDecoder().decode(G2PJSON.self, from: data)
        self.dictionary = json.entries
    }

    /// Инициализирует G2PWorker с внедрённым словарём (для тестов).
    public init(dictionary: [String: [String]]) {
        self.dictionary = dictionary
    }

    // MARK: - Public API

    /// Транскрибирует русское слово в массив IPA фонем.
    /// - Parameter word: слово на русском языке (любой регистр)
    /// - Returns: массив ``Phoneme`` в порядке произношения
    public func transcribe(_ word: String) async throws -> [Phoneme] {
        let normalized = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if let phonemes = dictionary[normalized] {
            return phonemes.enumerated().map { Phoneme(ipa: $0.element, position: $0.offset) }
        }

        // Fallback: правиловой G2P
        logger.info("G2PWorker: '\(normalized)' не в словаре, применяется rule-based fallback")
        let fallbackPhonemes = ruleBased(normalized)
        return fallbackPhonemes.enumerated().map { Phoneme(ipa: $0.element, position: $0.offset) }
    }

    /// Возвращает количество записей в словаре.
    public var dictionaryCount: Int { dictionary.count }

    /// Проверяет, есть ли слово в словаре.
    public func contains(_ word: String) -> Bool {
        let normalized = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return dictionary[normalized] != nil
    }

    // MARK: - Rule-based Fallback

    private func ruleBased(_ word: String) -> [String] {
        let chars = Array(word.unicodeScalars.map { Character($0) })
        let vowels: Set<Character> = ["а", "е", "ё", "и", "о", "у", "ы", "э", "ю", "я"]
        var result: [String] = []
        var idx = 0

        while idx < chars.count {
            let ch = chars[idx]
            let isLast = (idx == chars.count - 1)
            let nextCh: Character? = idx + 1 < chars.count ? chars[idx + 1] : nil
            let isBeforeSoft = nextCh.map { ["е", "ё", "и", "ю", "я", "ь"].contains($0) } ?? false
            let phonemes = ruleBasedPhonemes(
                ch: ch,
                idx: idx,
                isLast: isLast,
                isBeforeSoft: isBeforeSoft,
                chars: chars,
                vowels: vowels
            )
            result.append(contentsOf: phonemes)
            idx += 1
        }

        return result.isEmpty ? ["a"] : result
    }

    // swiftlint:disable cyclomatic_complexity function_parameter_count
    private func ruleBasedPhonemes(
        ch: Character,
        idx: Int,
        isLast: Bool,
        isBeforeSoft: Bool,
        chars: [Character],
        vowels: Set<Character>
    ) -> [String] {
        switch ch {
        // Шипящие
        case "ш": return ["ʂ"]
        case "щ": return ["ɕː"]
        case "ж": return ["ʐ"]
        case "ч": return ["tɕ"]
        // Свистящие
        case "з": return [isLast ? "s" : "z"]
        case "с": return [isBeforeSoft ? "sʲ" : "s"]
        case "ц": return ["ts"]
        // Соноры
        case "р": return [isBeforeSoft ? "rʲ" : "r"]
        case "л": return [isBeforeSoft ? "lʲ" : "l"]
        case "м": return [isBeforeSoft ? "mʲ" : "m"]
        case "н": return [isBeforeSoft ? "nʲ" : "n"]
        // Заднеязычные
        case "к": return [isBeforeSoft ? "kʲ" : "k"]
        case "г": return [isLast ? "k" : (isBeforeSoft ? "gʲ" : "g")]
        case "х": return [isBeforeSoft ? "xʲ" : "x"]
        // Губные
        case "б": return [isLast ? "p" : (isBeforeSoft ? "bʲ" : "b")]
        case "п": return [isBeforeSoft ? "pʲ" : "p"]
        case "в": return [isLast ? "f" : (isBeforeSoft ? "vʲ" : "v")]
        case "ф": return [isBeforeSoft ? "fʲ" : "f"]
        // Зубные
        case "д": return [isLast ? "t" : (isBeforeSoft ? "dʲ" : "d")]
        case "т": return [isBeforeSoft ? "tʲ" : "t"]
        // Гласные
        case "а": return ["a"]
        case "о": return [idx == 0 ? "o" : "ə"]
        case "у": return ["u"]
        case "и": return ["i"]
        case "ы": return ["ɨ"]
        case "э": return ["e"]
        // Йотированные гласные
        case "е":
            let prevIsVowel = idx > 0 && vowels.contains(chars[idx - 1])
            return (idx == 0 || prevIsVowel) ? ["j", "e"] : ["e"]
        case "ё":
            let prevIsVowel = idx > 0 && vowels.contains(chars[idx - 1])
            return (idx == 0 || prevIsVowel) ? ["j", "o"] : ["o"]
        case "ю":
            let prevIsVowel = idx > 0 && vowels.contains(chars[idx - 1])
            return (idx == 0 || prevIsVowel) ? ["j", "u"] : ["u"]
        case "я":
            let prevIsVowel = idx > 0 && vowels.contains(chars[idx - 1])
            return (idx == 0 || prevIsVowel) ? ["j", "a"] : ["æ"]
        case "й": return ["j"]
        // Мягкий/твёрдый знак — не дают отдельной фонемы
        case "ь", "ъ": return []
        default: return []
        }
    }
    // swiftlint:enable cyclomatic_complexity function_parameter_count
}

// MARK: - G2PJSON

/// Структура JSON словаря `russian_phonemes.json`.
private struct G2PJSON: Codable {
    let version: Int
    let language: String
    let alphabet: String
    let entries: [String: [String]]
}
