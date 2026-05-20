@testable import HappySpeech
import Foundation
import Testing

// MARK: - Spy

@MainActor
private final class SpyBilingualModeDisplay: BilingualModeDisplayLogic, @unchecked Sendable {

    var loadVM: BilingualModeModels.LoadVocabulary.ViewModel?
    var startVM: BilingualModeModels.StartPractice.ViewModel?
    var answerVM: BilingualModeModels.SubmitAnswer.ViewModel?
    var finishVM: BilingualModeModels.FinishPractice.ViewModel?

    func displayLoadVocabulary(viewModel: BilingualModeModels.LoadVocabulary.ViewModel) async {
        loadVM = viewModel
    }
    func displayStartPractice(viewModel: BilingualModeModels.StartPractice.ViewModel) async {
        startVM = viewModel
    }
    func displaySubmitAnswer(viewModel: BilingualModeModels.SubmitAnswer.ViewModel) async {
        answerVM = viewModel
    }
    func displayFinishPractice(viewModel: BilingualModeModels.FinishPractice.ViewModel) async {
        finishVM = viewModel
    }
}

// MARK: - Corpus tests

@Suite("BilingualMode — Corpus")
struct BilingualVocabularyCorpusSuite {

    @Test func corpus_has_atLeast30_words() {
        let count = BilingualVocabularyCorpus.words.count
        #expect(count >= 30, "Корпус должен содержать минимум 30 слов, факт: \(count)")
    }

    @Test func every_word_has_belarusian_translation() {
        for word in BilingualVocabularyCorpus.words {
            let translation = word.translation(for: .belarusian)
            #expect(translation != nil && !(translation ?? "").isEmpty,
                    "У слова \(word.russian) нет перевода на белорусский")
        }
    }

    @Test func every_word_has_english_translation() {
        for word in BilingualVocabularyCorpus.words {
            let translation = word.translation(for: .english)
            #expect(translation != nil && !(translation ?? "").isEmpty,
                    "У слова \(word.russian) нет перевода на английский")
        }
    }

    @Test func off_language_yields_no_translation() {
        guard let first = BilingualVocabularyCorpus.words.first else {
            Issue.record("Empty corpus")
            return
        }
        #expect(first.translation(for: .off) == nil)
    }

    @Test func grouped_skips_empty_categories() {
        let grouped = BilingualVocabularyCorpus.grouped(for: .english)
        for entry in grouped {
            #expect(!entry.items.isEmpty, "Категория \(entry.category) пуста")
        }
    }

    @Test func words_for_off_language_isEmpty() {
        #expect(BilingualVocabularyCorpus.words(for: .off).isEmpty)
    }

    @Test func categories_in_order_are_non_empty() {
        #expect(!BilingualVocabularyCorpus.categoriesInOrder.isEmpty)
    }
}

// MARK: - PracticeGenerator tests

@Suite("BilingualMode — PracticeGenerator")
struct BilingualPracticeGeneratorSuite {

    /// Простой детерминированный RNG — конкатенирует seed по-биту.
    /// Для проверочных целей более чем достаточно: даёт стабильные тестовые
    /// выводы без зависимостей от системного rand().
    private struct SeedRNG: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            // Простой xorshift64.
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return state
        }
    }

    @Test func makeRounds_off_yields_empty() {
        var rng = SeedRNG(state: 42)
        let rounds = BilingualPracticeGenerator.makeRounds(
            for: .off,
            count: 10,
            using: &rng
        )
        #expect(rounds.isEmpty)
    }

    @Test func makeRounds_returns_requested_count_for_english() {
        var rng = SeedRNG(state: 42)
        let rounds = BilingualPracticeGenerator.makeRounds(
            for: .english,
            count: 10,
            using: &rng
        )
        #expect(rounds.count == 10)
    }

    @Test func every_round_has_three_options() {
        var rng = SeedRNG(state: 7)
        let rounds = BilingualPracticeGenerator.makeRounds(
            for: .english,
            count: 5,
            using: &rng
        )
        for round in rounds {
            #expect(round.options.count == BilingualPracticeGenerator.optionsPerRound)
        }
    }

    @Test func correct_option_is_in_options_set() {
        var rng = SeedRNG(state: 7)
        let rounds = BilingualPracticeGenerator.makeRounds(
            for: .english,
            count: 5,
            using: &rng
        )
        for round in rounds {
            #expect(round.options.contains { $0.id == round.correctOptionId },
                    "У раунда \(round.id) нет корректной опции в списке вариантов")
        }
    }

    @Test func correct_translation_matches_word_translation() {
        var rng = SeedRNG(state: 7)
        let rounds = BilingualPracticeGenerator.makeRounds(
            for: .belarusian,
            count: 6,
            using: &rng
        )
        for round in rounds {
            let expected = round.word.translation(for: .belarusian)
            let correct = round.options.first { $0.id == round.correctOptionId }?.translation
            #expect(expected == correct,
                    "Для слова \(round.word.russian) опция-correct (\(correct ?? "")) != translation (\(expected ?? ""))")
        }
    }

    // MARK: Stars thresholds

    @Test func stars_perfectScore_yields_three() {
        #expect(BilingualPracticeGenerator.stars(correctCount: 10, totalRounds: 10) == 3)
    }

    @Test func stars_six_to_nine_yields_two() {
        #expect(BilingualPracticeGenerator.stars(correctCount: 6, totalRounds: 10) == 2)
        #expect(BilingualPracticeGenerator.stars(correctCount: 7, totalRounds: 10) == 2)
        #expect(BilingualPracticeGenerator.stars(correctCount: 9, totalRounds: 10) == 2)
    }

    @Test func stars_three_to_five_yields_one() {
        #expect(BilingualPracticeGenerator.stars(correctCount: 3, totalRounds: 10) == 1)
        #expect(BilingualPracticeGenerator.stars(correctCount: 4, totalRounds: 10) == 1)
        #expect(BilingualPracticeGenerator.stars(correctCount: 5, totalRounds: 10) == 1)
    }

    @Test func stars_lessThan_three_yields_zero() {
        #expect(BilingualPracticeGenerator.stars(correctCount: 0, totalRounds: 10) == 0)
        #expect(BilingualPracticeGenerator.stars(correctCount: 1, totalRounds: 10) == 0)
        #expect(BilingualPracticeGenerator.stars(correctCount: 2, totalRounds: 10) == 0)
    }

    @Test func stars_with_zero_totalRounds_yields_zero() {
        #expect(BilingualPracticeGenerator.stars(correctCount: 5, totalRounds: 0) == 0)
    }
}

// MARK: - Interactor tests

@Suite("BilingualMode — Interactor")
@MainActor
struct BilingualModeInteractorSuite {

    /// Изолированный UserDefaults для каждого теста, чтобы не задеть основной.
    private func makeDefaults(suite: String) -> UserDefaults {
        UserDefaults.standard.removePersistentDomain(forName: suite)
        guard let defaults = UserDefaults(suiteName: suite) else {
            return UserDefaults.standard
        }
        return defaults
    }

    private func makeSUT(
        suite: String,
        preset: BilingualSecondLanguage? = nil
    ) -> (BilingualModeInteractor, SpyBilingualModeDisplay) {
        let defaults = makeDefaults(suite: suite)
        if let preset {
            defaults.set(preset.rawValue, forKey: BilingualModeInteractor.userDefaultsKey)
        }
        let spy = SpyBilingualModeDisplay()
        let presenter = BilingualModePresenter(displayLogic: spy)
        let interactor = BilingualModeInteractor(presenter: presenter, defaults: defaults)
        return (interactor, spy)
    }

    @Test func default_secondLanguage_is_off() async {
        let (sut, _) = makeSUT(suite: "test.bilingual.default")
        #expect(sut.secondLanguage == .off)
    }

    @Test func setSecondLanguage_persists_to_defaults() async {
        let suite = "test.bilingual.persist"
        let (sut, _) = makeSUT(suite: suite)
        await sut.setSecondLanguage(.belarusian)
        let stored = UserDefaults(suiteName: suite)?
            .string(forKey: BilingualModeInteractor.userDefaultsKey)
        #expect(stored == BilingualSecondLanguage.belarusian.rawValue)
    }

    @Test func init_restores_secondLanguage_from_defaults() async {
        let suite = "test.bilingual.restore"
        let (sut, _) = makeSUT(suite: suite, preset: .english)
        #expect(sut.secondLanguage == .english)
    }

    @Test func loadVocabulary_presents_words_for_current_language() async {
        let (sut, spy) = makeSUT(suite: "test.bilingual.load", preset: .english)
        await sut.loadVocabulary()
        #expect(spy.loadVM != nil)
        #expect(spy.loadVM?.secondLanguage == .english)
        let totalGroupedCount = spy.loadVM?.grouped.values.reduce(0) { $0 + $1.count } ?? 0
        #expect(totalGroupedCount > 0)
    }

    @Test func loadVocabulary_off_yields_empty_grouped() async {
        let (sut, spy) = makeSUT(suite: "test.bilingual.loadOff", preset: .off)
        await sut.loadVocabulary()
        let totalGroupedCount = spy.loadVM?.grouped.values.reduce(0) { $0 + $1.count } ?? 0
        #expect(totalGroupedCount == 0)
    }

    @Test func startPractice_when_off_does_nothing() async {
        let (sut, spy) = makeSUT(suite: "test.bilingual.startOff", preset: .off)
        await sut.startPractice(totalRounds: 10)
        #expect(spy.startVM == nil)
        #expect(sut.totalRoundsCount == 0)
    }

    @Test func startPractice_generates_rounds() async {
        let (sut, spy) = makeSUT(suite: "test.bilingual.start", preset: .english)
        await sut.startPractice(totalRounds: 10)
        #expect(spy.startVM?.totalRounds == 10)
        #expect(sut.totalRoundsCount == 10)
    }

    @Test func submitAnswer_correct_increments_count() async {
        let (sut, _) = makeSUT(suite: "test.bilingual.answerCorrect", preset: .english)
        await sut.startPractice(totalRounds: 3)
        for index in 0..<sut.totalRoundsCount {
            // Берём reference на rounds через инжект (для прозрачности).
            let injected = (0..<3).map { idx in
                BilingualPracticeRound(
                    id: "r\(idx)",
                    word: BilingualVocabularyCorpus.words[0],
                    options: [
                        BilingualPracticeOption(id: "c", translation: "correct"),
                        BilingualPracticeOption(id: "d1", translation: "d1"),
                        BilingualPracticeOption(id: "d2", translation: "d2")
                    ],
                    correctOptionId: "c"
                )
            }
            // Инжектим только один раз, на индексе 0.
            if index == 0 {
                await sut.injectPractice(rounds: injected)
            }
            let result = await sut.submitAnswer(roundIndex: index, selectedOptionId: "c")
            #expect(result)
        }
        #expect(sut.correctAnswersCount == 3)
    }

    @Test func submitAnswer_outOfRange_is_safe() async {
        let (sut, _) = makeSUT(suite: "test.bilingual.outOfRange", preset: .english)
        let ok = await sut.submitAnswer(roundIndex: 999, selectedOptionId: "x")
        #expect(!ok)
    }

    @Test func finishPractice_with_all_correct_yields_3stars() async {
        let (sut, spy) = makeSUT(suite: "test.bilingual.finishAll", preset: .english)
        let injected = (0..<10).map { idx in
            BilingualPracticeRound(
                id: "r\(idx)",
                word: BilingualVocabularyCorpus.words[0],
                options: [
                    BilingualPracticeOption(id: "c", translation: "correct"),
                    BilingualPracticeOption(id: "d1", translation: "d1"),
                    BilingualPracticeOption(id: "d2", translation: "d2")
                ],
                correctOptionId: "c"
            )
        }
        await sut.injectPractice(rounds: injected)
        for index in 0..<10 {
            await sut.submitAnswer(roundIndex: index, selectedOptionId: "c")
        }
        await sut.finishPractice()
        #expect(spy.finishVM?.stars == 3)
        #expect(spy.finishVM?.correctCount == 10)
        #expect(spy.finishVM?.totalRounds == 10)
    }

    @Test func finishPractice_with_half_correct_yields_2stars() async {
        let (sut, spy) = makeSUT(suite: "test.bilingual.finishHalf", preset: .english)
        let injected = (0..<10).map { idx in
            BilingualPracticeRound(
                id: "r\(idx)",
                word: BilingualVocabularyCorpus.words[0],
                options: [
                    BilingualPracticeOption(id: "c", translation: "correct"),
                    BilingualPracticeOption(id: "d", translation: "d")
                ],
                correctOptionId: "c"
            )
        }
        await sut.injectPractice(rounds: injected)
        for index in 0..<6 {
            await sut.submitAnswer(roundIndex: index, selectedOptionId: "c")
        }
        for index in 6..<10 {
            await sut.submitAnswer(roundIndex: index, selectedOptionId: "d")
        }
        await sut.finishPractice()
        #expect(spy.finishVM?.stars == 2)
        #expect(spy.finishVM?.correctCount == 6)
    }

    @Test func finishPractice_with_none_correct_yields_0stars() async {
        let (sut, spy) = makeSUT(suite: "test.bilingual.finishZero", preset: .english)
        let injected = (0..<10).map { idx in
            BilingualPracticeRound(
                id: "r\(idx)",
                word: BilingualVocabularyCorpus.words[0],
                options: [
                    BilingualPracticeOption(id: "c", translation: "correct"),
                    BilingualPracticeOption(id: "d", translation: "d")
                ],
                correctOptionId: "c"
            )
        }
        await sut.injectPractice(rounds: injected)
        for index in 0..<10 {
            await sut.submitAnswer(roundIndex: index, selectedOptionId: "d")
        }
        await sut.finishPractice()
        #expect(spy.finishVM?.stars == 0)
        #expect(spy.finishVM?.correctCount == 0)
    }
}

// MARK: - Presenter tests

@Suite("BilingualMode — Presenter")
@MainActor
struct BilingualModePresenterSuite {

    private func makeSUT() -> (BilingualModePresenter, SpyBilingualModeDisplay) {
        let spy = SpyBilingualModeDisplay()
        let presenter = BilingualModePresenter(displayLogic: spy)
        return (presenter, spy)
    }

    @Test func presentLoadVocabulary_groups_by_category() async {
        let (presenter, spy) = makeSUT()
        let words = BilingualVocabularyCorpus.words(for: .english)
        await presenter.presentLoadVocabulary(
            response: .init(secondLanguage: .english, words: words)
        )
        #expect(spy.loadVM != nil)
        #expect(spy.loadVM?.secondLanguage == .english)
        #expect(spy.loadVM?.categoriesInOrder.isEmpty == false)
        for category in spy.loadVM?.categoriesInOrder ?? [] {
            #expect(spy.loadVM?.grouped[category]?.isEmpty == false)
        }
    }

    @Test func presentStartPractice_preserves_round_count() async {
        let (presenter, spy) = makeSUT()
        let word = BilingualVocabularyCorpus.words[0]
        let rounds = (0..<5).map { idx in
            BilingualPracticeRound(
                id: "r\(idx)", word: word, options: [], correctOptionId: ""
            )
        }
        await presenter.presentStartPractice(
            response: .init(secondLanguage: .english, rounds: rounds)
        )
        #expect(spy.startVM?.totalRounds == 5)
        #expect(spy.startVM?.rounds.count == 5)
    }

    @Test func presentSubmitAnswer_forwards_correctness() async {
        let (presenter, spy) = makeSUT()
        await presenter.presentSubmitAnswer(
            response: .init(roundIndex: 2, isCorrect: true, correctTranslation: "house")
        )
        #expect(spy.answerVM?.roundIndex == 2)
        #expect(spy.answerVM?.isCorrect == true)
        #expect(spy.answerVM?.correctTranslation == "house")
    }

    @Test func presentFinishPractice_computes_stars_and_text() async {
        let (presenter, spy) = makeSUT()
        await presenter.presentFinishPractice(
            response: .init(correctCount: 10, totalRounds: 10, secondLanguage: .english)
        )
        #expect(spy.finishVM?.stars == 3)
        #expect(spy.finishVM?.title.isEmpty == false)
        #expect(spy.finishVM?.body.isEmpty == false)
    }
}
