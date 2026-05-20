import Foundation

// MARK: - LexicalDiversityCalculator
//
// Считает Type-Token Ratio (TTR) = unique_words / total_words.
//
// Простая, методически достаточная метрика лексического разнообразия
// для детской устной речи (Sago Mini / SLP-журналы).
//
// Нормализация:
//   • lowercased
//   • удаление пунктуации
//   • схлопывание whitespace
//   • Unicode-нормализация (NFC)

struct LexicalDiversityCalculator: Sendable {

    /// Возвращает (totalWords, uniqueWords, ttr).
    /// Если totalWords == 0 — ttr = 0.
    func analyse(transcript: String) -> (total: Int, unique: Int, ttr: Double) {
        let words = tokenise(transcript)
        let unique = Set(words).count
        let total = words.count
        guard total > 0 else { return (0, 0, 0) }
        return (total, unique, Double(unique) / Double(total))
    }

    // MARK: - Helpers

    /// Разбивает строку на слова. Только буквы (рус/lat) и дефис.
    func tokenise(_ text: String) -> [String] {
        let normalised = text
            .lowercased()
            .precomposedStringWithCanonicalMapping
        let allowed = CharacterSet.letters.union(CharacterSet(charactersIn: "-"))
        let cleaned = normalised.unicodeScalars
            .map { allowed.contains($0) ? Character($0) : Character(" ") }
        let words = String(cleaned)
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
            .filter { !$0.isEmpty && $0 != "-" }
        return words
    }
}
