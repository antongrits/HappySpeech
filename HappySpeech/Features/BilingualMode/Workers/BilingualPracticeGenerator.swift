import Foundation

// MARK: - BilingualPracticeGenerator
//
// Чисто-функциональный генератор раундов тренировки. Удобен для unit-тестов
// (детерминирован через seed) и для Interactor.

struct BilingualPracticeGenerator {

    /// Стандартный размер сессии тренировки (по ТЗ — 10 раундов).
    static let defaultRoundsCount: Int = 10

    /// Сколько вариантов ответа в раунде (1 правильный + 2 дистрактора).
    static let optionsPerRound: Int = 3

    /// Сколько максимум корректных ответов даёт 3 ★, 2 ★, 1 ★.
    /// По ТЗ: 10 = 3★, 6-9 = 2★, 3-5 = 1★, <3 = 0★.
    static func stars(correctCount: Int, totalRounds: Int) -> Int {
        guard totalRounds > 0 else { return 0 }
        // Если у нас не 10 раундов, нормируем порог пропорционально.
        let ratio = Double(correctCount) / Double(totalRounds)
        if correctCount == totalRounds { return 3 }
        if ratio >= 0.6 { return 2 }
        if ratio >= 0.3 { return 1 }
        return 0
    }

    /// Генерирует раунды для указанного языка. Если слов в корпусе меньше,
    /// чем нужно — добирает с повторениями. Дистракторы выбираются из
    /// того же корпуса, исключая правильный ответ.
    ///
    /// `rng` — источник псевдослучайности. Для production — `SystemRandomNumberGenerator`,
    /// для тестов — детерминированный seedable RNG.
    static func makeRounds<G: RandomNumberGenerator>(
        for language: BilingualSecondLanguage,
        count requestedCount: Int = defaultRoundsCount,
        using rng: inout G,
        corpus: [BilingualWord] = BilingualVocabularyCorpus.words
    ) -> [BilingualPracticeRound] {
        guard language != .off else { return [] }
        let count = max(1, requestedCount)
        let pool = corpus.filter { $0.translation(for: language) != nil }
        guard !pool.isEmpty else { return [] }

        let shuffled = pool.shuffled(using: &rng)
        var rounds: [BilingualPracticeRound] = []
        rounds.reserveCapacity(count)
        for index in 0..<count {
            let word = shuffled[index % shuffled.count]
            let round = makeRound(
                word: word,
                index: index,
                language: language,
                pool: pool,
                using: &rng
            )
            rounds.append(round)
        }
        return rounds
    }

    /// Удобный вариант с системным RNG.
    static func makeRounds(
        for language: BilingualSecondLanguage,
        count: Int = defaultRoundsCount,
        corpus: [BilingualWord] = BilingualVocabularyCorpus.words
    ) -> [BilingualPracticeRound] {
        var rng = SystemRandomNumberGenerator()
        return makeRounds(for: language, count: count, using: &rng, corpus: corpus)
    }

    // MARK: - Helpers

    private static func makeRound<G: RandomNumberGenerator>(
        word: BilingualWord,
        index: Int,
        language: BilingualSecondLanguage,
        pool: [BilingualWord],
        using rng: inout G
    ) -> BilingualPracticeRound {
        // Правильный перевод. force-unwrap не используем — guard выше уже отсёк.
        let correctTranslation = word.translation(for: language) ?? word.russian
        let correctOption = BilingualPracticeOption(
            id: "\(word.id)#\(index)#correct",
            translation: correctTranslation
        )

        // Дистракторы — берём из других слов корпуса.
        let others = pool.filter { $0.id != word.id }
        let distractors: [BilingualWord] = Array(others.shuffled(using: &rng).prefix(2))
        let distractorOptions = distractors.enumerated().map { (offset, otherWord) in
            BilingualPracticeOption(
                id: "\(word.id)#\(index)#d\(offset)",
                translation: otherWord.translation(for: language) ?? otherWord.russian
            )
        }

        // Финальные опции — перемешаны.
        let options = ([correctOption] + distractorOptions).shuffled(using: &rng)
        return BilingualPracticeRound(
            id: "round-\(index)-\(word.id)",
            word: word,
            options: options,
            correctOptionId: correctOption.id
        )
    }
}
