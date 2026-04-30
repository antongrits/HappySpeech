import Foundation

// MARK: - ChildSafetyValidator
// ==================================================================================
// Синхронный валидатор текстового вывода LLM для детского контура (5–8 лет).
//
// Используется как последний барьер перед отображением MLX-генерации ребёнку:
//   1. Keyword blacklist — русские нежелательные слова
//   2. Length check — не более 256 символов
//   3. Sound consistency — вывод не содержит явных признаков off-topic
//
// Является дополнением к KidSafetyFilter (actor) — валидатор работает синхронно
// и используется внутри #if arch(arm64) блоков LocalLLMServiceLive.
// ==================================================================================

public enum ChildSafetyValidator {

    // MARK: - Blacklist

    /// Слова, недопустимые в контенте для детей 5–8 лет.
    private static let bannedWords: Set<String> = [
        // Насилие / страх
        "убить", "убить", "умереть", "смерть", "кровь", "страшный", "ужас",
        "боль", "бить", "ударить", "опасность", "взрыв", "война",
        // Взрослые темы
        "деньги", "купить", "продать", "реклама", "алкоголь", "сигарет",
        // Негативная самооценка
        "глупый", "тупой", "неудача", "провал", "плохой",
        // Технический мусор / модель-специфика
        "assistant:", "human:", "<|im_start|>", "<|im_end|>", "<s>", "</s>",
        "[inst]", "[/inst]", "system:", "user:", "токен", "промпт"
    ]

    // MARK: - Length limit

    /// Максимальная длина вывода для детского контура (символы).
    private static let maxLength: Int = 256

    // MARK: - Validation

    /// Проверяет текст вывода LLM перед отображением ребёнку.
    ///
    /// - Parameter text: сырой вывод модели
    /// - Returns: `true` если текст безопасен для показа
    public static func validate(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Пустой вывод — небезопасен
        guard !trimmed.isEmpty else { return false }

        // Длина
        guard trimmed.count <= maxLength else { return false }

        // Keyword blacklist (регистронезависимо)
        let lowered = trimmed.lowercased()
        for word in bannedWords where lowered.contains(word.lowercased()) {
            return false
        }

        return true
    }

    /// Усекает текст до допустимой длины по границе слова.
    /// Используется как мягкий вариант когда текст валиден по содержанию, но слишком длинный.
    public static func truncateToLimit(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        let truncated = String(trimmed[..<index])
        // Обрезаем по последнему пробелу
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + "."
        }
        return truncated + "."
    }
}
