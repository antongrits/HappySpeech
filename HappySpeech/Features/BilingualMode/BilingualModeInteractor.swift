import Foundation
import OSLog

// MARK: - BilingualModeInteractor
//
// VIP-Interactor для «Билингвального режима».
//
// Ответственность:
//   - читает/пишет выбор второго языка в `UserDefaults`
//     под ключом `"bilingualMode.secondLanguage"`;
//   - подгружает словарь через `BilingualVocabularyCorpus`;
//   - запускает practice-режим: генерирует раунды, ведёт счёт, отдаёт
//     результат в Presenter.

@MainActor
final class BilingualModeInteractor {

    /// Ключ в UserDefaults для выбранного второго языка.
    static let userDefaultsKey = "bilingualMode.secondLanguage"

    // MARK: - Dependencies

    private let presenter: BilingualModePresenter
    private let defaults: UserDefaults

    private let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "BilingualMode.Interactor"
    )

    // MARK: - State

    private(set) var secondLanguage: BilingualSecondLanguage
    private var rounds: [BilingualPracticeRound] = []
    private var answered: [Bool] = []

    // MARK: - Init

    init(
        presenter: BilingualModePresenter,
        defaults: UserDefaults = .standard
    ) {
        self.presenter = presenter
        self.defaults = defaults
        let raw = defaults.string(forKey: Self.userDefaultsKey) ?? BilingualSecondLanguage.off.rawValue
        self.secondLanguage = BilingualSecondLanguage(rawValue: raw) ?? .off
    }

    // MARK: - Load

    /// Презентует загрузку словаря для текущего выбора второго языка.
    func loadVocabulary() async {
        let words = BilingualVocabularyCorpus.words(for: secondLanguage)
        await presenter.presentLoadVocabulary(
            response: .init(secondLanguage: secondLanguage, words: words)
        )
    }

    // MARK: - Mutate language

    /// Меняет второй язык и сохраняет в UserDefaults.
    func setSecondLanguage(_ language: BilingualSecondLanguage) async {
        guard language != secondLanguage else { return }
        secondLanguage = language
        defaults.set(language.rawValue, forKey: Self.userDefaultsKey)
        logger.info("setSecondLanguage \(language.rawValue, privacy: .public)")
        // Сбрасываем активную тренировку, т. к. словарь сменился.
        rounds = []
        answered = []
        await loadVocabulary()
    }

    // MARK: - Practice

    /// Стартует practice-сессию с 10 раундами (или указанным числом).
    func startPractice(totalRounds: Int = BilingualPracticeGenerator.defaultRoundsCount) async {
        guard secondLanguage != .off else {
            logger.warning("startPractice ignored — secondLanguage is .off")
            return
        }
        let newRounds = BilingualPracticeGenerator.makeRounds(
            for: secondLanguage,
            count: totalRounds
        )
        rounds = newRounds
        answered = Array(repeating: false, count: newRounds.count)
        await presenter.presentStartPractice(
            response: .init(secondLanguage: secondLanguage, rounds: newRounds)
        )
    }

    /// Тест-friendly вариант: позволяет заинжектить готовые раунды
    /// (например, из детерминированного генератора в unit-тесте).
    func injectPractice(rounds injectedRounds: [BilingualPracticeRound]) async {
        rounds = injectedRounds
        answered = Array(repeating: false, count: injectedRounds.count)
        await presenter.presentStartPractice(
            response: .init(secondLanguage: secondLanguage, rounds: injectedRounds)
        )
    }

    /// Регистрирует ответ. Возвращает true/false для удобства тестов.
    @discardableResult
    func submitAnswer(roundIndex: Int, selectedOptionId: String) async -> Bool {
        guard roundIndex >= 0, roundIndex < rounds.count else {
            logger.error("submitAnswer: out-of-range index \(roundIndex)")
            return false
        }
        let round = rounds[roundIndex]
        let isCorrect = (selectedOptionId == round.correctOptionId)
        answered[roundIndex] = isCorrect
        await presenter.presentSubmitAnswer(
            response: .init(
                roundIndex: roundIndex,
                isCorrect: isCorrect,
                correctTranslation: correctTranslation(for: round)
            )
        )
        return isCorrect
    }

    /// Завершает тренировку и презентует финальный score.
    func finishPractice() async {
        let correctCount = answered.filter { $0 }.count
        await presenter.presentFinishPractice(
            response: .init(
                correctCount: correctCount,
                totalRounds: rounds.count,
                secondLanguage: secondLanguage
            )
        )
    }

    // MARK: - Read-only helpers

    var totalRoundsCount: Int { rounds.count }
    var correctAnswersCount: Int { answered.filter { $0 }.count }

    // MARK: - Private

    private func correctTranslation(for round: BilingualPracticeRound) -> String {
        round.options.first { $0.id == round.correctOptionId }?.translation
            ?? round.word.translation(for: secondLanguage)
            ?? round.word.russian
    }
}
