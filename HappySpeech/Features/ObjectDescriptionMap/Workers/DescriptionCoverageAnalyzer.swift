import Foundation

// MARK: - DescriptionCoverageAnalyzer
//
// Анализирует транскрипт детского описания против плана-схемы Ткаченко
// и возвращает `DescriptionCoverageReport`: какие пункты закрыты, общее
// число слов, среднюю длину предложения, лексическое разнообразие.
//
// Алгоритм:
//   1. Нормализация транскрипта (lowercase, NFC, схлопывание пунктуации,
//      нормализация «ё» → «е»).
//   2. Токенизация на слова (буквы + дефис).
//   3. Для каждого пункта плана — substring-поиск любого из его keywords
//      в нормализованном тексте (либо точное совпадение токена для
//      однословных keywords). Пункт считается «закрытым», если совпал
//      хотя бы один keyword.
//   4. Подсчёт totalWords, uniqueWords (TTR), числа предложений
//      (разделители . ! ?), avg sentence length = words / sentences.
//
// Запускается на детской устной речи 5–8 лет — где WhisperKit может
// исказить лексику. Поэтому substring-поиск + нормализация «ё/е», а не
// строгий PoS-tag.

struct DescriptionCoverageAnalyzer: Sendable {

    // MARK: - Public

    func analyse(
        transcript: String,
        plan: [DescriptionPlanItem]
    ) -> DescriptionCoverageReport {
        let normalised = Self.normalise(transcript)
        let tokens = Self.tokenise(normalised)
        let sentenceCount = max(1, Self.countSentences(in: transcript))
        let unique = Set(tokens).count
        let total = tokens.count
        let ttr = total > 0 ? Double(unique) / Double(total) : 0
        let avgSentence = total > 0 ? Double(total) / Double(sentenceCount) : 0

        let decorated: [DecoratedPlanItem] = plan.map { item in
            let matched = item.keywords.filter { keyword in
                contains(haystack: normalised, tokens: tokens, needle: keyword)
            }
            return DecoratedPlanItem(
                item: item,
                isCovered: !matched.isEmpty,
                matchedKeywords: matched
            )
        }
        let covered = decorated.filter(\.isCovered).count

        return DescriptionCoverageReport(
            decorated: decorated,
            coveredCount: covered,
            totalCount: plan.count,
            totalWords: total,
            avgSentenceLengthWords: avgSentence,
            lexicalDiversity: ttr
        )
    }

    /// Конвертация доли покрытия в звёзды 0…3.
    ///
    /// - 0 звёзд: <25% или транскрипт пуст.
    /// - 1 звезда: 25…49%.
    /// - 2 звезды: 50…79%.
    /// - 3 звезды: ≥80%.
    func stars(forRatio ratio: Double) -> Int {
        guard ratio > 0 else { return 0 }
        if ratio >= 0.80 { return 3 }
        if ratio >= 0.50 { return 2 }
        if ratio >= 0.25 { return 1 }
        return 0
    }

    // MARK: - Matching

    private func contains(haystack: String, tokens: [String], needle raw: String) -> Bool {
        let needle = Self.normalise(raw)
        guard !needle.isEmpty else { return false }
        // Многословное keyword — substring-поиск.
        if needle.contains(" ") {
            return haystack.contains(needle)
        }
        // Однословное keyword — substring-поиск по нормализованному
        // тексту (учитывает падежные окончания: «рыжий» → «рыжего»).
        // Минимальная длина 3 символа — иначе ловим артикли «и», «в».
        guard needle.count >= 3 else {
            return tokens.contains(needle)
        }
        // Префиксный матч по любому из токенов (даёт грубую устойчивость
        // к словоформам: «рыж» матчит «рыжий», «рыжего», «рыжая»).
        let stem = String(needle.prefix(max(3, needle.count - 2)))
        for token in tokens where token.hasPrefix(stem) {
            return true
        }
        return haystack.contains(needle)
    }

    // MARK: - Normalisation

    static func normalise(_ raw: String) -> String {
        let lowered = raw.lowercased().precomposedStringWithCanonicalMapping
        // ё → е для устойчивости к транскрипции WhisperKit.
        let yoSafe = lowered.replacingOccurrences(of: "ё", with: "е")
        // Только буквы + дефис + пробел.
        let allowed = CharacterSet.letters
            .union(CharacterSet(charactersIn: "- "))
        let cleaned = yoSafe.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : Character(" ")
        }
        let collapsed = String(cleaned)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
        return collapsed
    }

    static func tokenise(_ normalised: String) -> [String] {
        normalised
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
            .filter { !$0.isEmpty && $0 != "-" }
    }

    static func countSentences(in raw: String) -> Int {
        let separators = CharacterSet(charactersIn: ".!?…")
        let parts = raw.unicodeScalars
            .split(whereSeparator: { separators.contains($0) })
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return max(parts.count, 1)
    }
}
