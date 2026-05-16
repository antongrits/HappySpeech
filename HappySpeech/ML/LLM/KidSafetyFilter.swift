import Foundation
import OSLog

// MARK: - KidSafetyFilter
// ==================================================================================
// Actor для sanitization LLM output в kid circuit.
// Удаляет / заменяет небезопасные слова, проверяет длину и структуру текста.
//
// COPPA compliance: никаких личных данных, только проверка выходного текста.
// Используется как последний барьер перед показом LLM-генерации ребёнку.
// ==================================================================================

public actor KidSafetyFilter {

    // MARK: - Configuration

    private static let bannedWords: Set<String> = [
        // Негативные эмоции, страх, насилие
        "плохо", "страшно", "ужасно", "убить", "умереть", "боль", "злой", "опасно", "страшный",
        // Взрослые темы
        "деньги", "купить", "продать", "реклама", "цена", "стоимость",
        // Технические/сленговые слова
        "лол", "чек", "юзер", "фейл", "баг", "краш", "дебаг",
        // Обидные слова
        "глупый", "плакать", "неудача", "провал"
    ]

    private static let maxWords: Int = 30
    private static let maxSentences: Int = 3

    private let logger = Logger(subsystem: "ru.happyspeech", category: "KidSafetyFilter")

    public init() {}

    // MARK: - Public API

    /// Проверяет текст и возвращает результат санитизации.
    public func sanitize(_ text: String) -> SanitizationResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .unsafe(reason: "empty_text")
        }

        // Разбиваем на слова и сравниваем по границам слова, а не подстрокой:
        // подстрочный поиск давал ложные срабатывания
        // (например «боль» внутри безопасного «большой»).
        let wordSeparators = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
        let loweredWords = text.lowercased()
            .components(separatedBy: wordSeparators)
            .filter { !$0.isEmpty }
        for word in loweredWords where Self.bannedWords.contains(word) {
            logger.warning("KidSafetyFilter banned word detected: \(word, privacy: .private)")
            return .unsafe(reason: "banned_word:\(word)")
        }

        let wordCount = text.split(separator: " ").count
        if wordCount > Self.maxWords {
            logger.info("KidSafetyFilter text too long: \(wordCount) words, truncating")
            return .needsTruncation(originalCount: wordCount)
        }

        let sentenceCount = text
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
        if sentenceCount > Self.maxSentences {
            logger.info("KidSafetyFilter too many sentences: \(sentenceCount), truncating")
            return .needsTruncation(originalCount: sentenceCount)
        }

        return .safe(text)
    }

    /// Усекает текст до maxWords слов, сохраняя конечный знак препинания.
    public func truncate(_ text: String) -> String {
        let words = text.split(separator: " ", omittingEmptySubsequences: true)
        guard words.count > Self.maxWords else { return text }
        let truncated = words.prefix(Self.maxWords).joined(separator: " ")
        // Добавляем точку если нет знака препинания в конце.
        let lastChar = truncated.last
        if let last = lastChar, ".!?".contains(last) {
            return truncated
        }
        return truncated + "."
    }

    // MARK: - SanitizationResult

    public enum SanitizationResult: Sendable {
        case safe(String)
        case needsTruncation(originalCount: Int)
        case unsafe(reason: String)
    }
}
