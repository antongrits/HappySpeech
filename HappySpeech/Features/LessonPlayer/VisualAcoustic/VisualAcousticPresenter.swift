import Foundation
import OSLog

// MARK: - VisualAcousticPresentationLogic

@MainActor
protocol VisualAcousticPresentationLogic: AnyObject {
    func presentLoadRound(_ response: VisualAcousticModels.LoadRound.Response)
    func presentPlayAudio(_ response: VisualAcousticModels.PlayAudio.Response)
    func presentChoiceWord(_ response: VisualAcousticModels.ChoiceWord.Response)
    func presentNextRound(_ response: VisualAcousticModels.NextRound.Response)
    func presentComplete(_ response: VisualAcousticModels.Complete.Response)
}

// MARK: - VisualAcousticPresenter
//
// Конвертирует Response → ViewModel и передаёт в `VisualAcousticDisplayLogic`.
// Вся бизнес-логика (каталог раундов, проверка выбора, счёт) — в Interactor.
// Здесь — только форматирование строк, локализация и шкала звёзд.

@MainActor
final class VisualAcousticPresenter: VisualAcousticPresentationLogic {

    weak var display: (any VisualAcousticDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "VisualAcousticPresenter")

    // MARK: - LoadRound

    func presentLoadRound(_ response: VisualAcousticModels.LoadRound.Response) {
        let round = response.round
        let progress = Self.progressFraction(
            roundIndex: response.roundIndex,
            totalRounds: response.totalRounds
        )
        let vm = VisualAcousticModels.LoadRound.ViewModel(
            imageEmoji: round.imageEmoji,
            imageLabel: round.imageLabel,
            question: round.question,
            questionWithSound: round.questionWithSound,
            choices: round.choices,
            roundIndex: response.roundIndex,
            totalRounds: response.totalRounds,
            progressFraction: progress
        )
        logger.info(
            "presentLoadRound round=\(response.roundIndex, privacy: .public)/\(response.totalRounds, privacy: .public) group=\(round.soundGroup, privacy: .public)"
        )
        display?.displayLoadRound(vm)
    }

    // MARK: - PlayAudio

    func presentPlayAudio(_ response: VisualAcousticModels.PlayAudio.Response) {
        let vm = VisualAcousticModels.PlayAudio.ViewModel(isPlaying: response.isPlaying)
        display?.displayPlayAudio(vm)
    }

    // MARK: - ChoiceWord

    func presentChoiceWord(_ response: VisualAcousticModels.ChoiceWord.Response) {
        // Формируем массив ChoiceResult из 4 слотов: правильный — зелёный,
        // неправильный — красный, если ребёнок ошибся — правильный
        // дополнительно подсвечивается золотом через wrong(correctIndex:).
        let slotCount = 4
        var results: [ChoiceResult] = Array(repeating: .none, count: slotCount)
        if response.isCorrect {
            if (0..<slotCount).contains(response.choiceIndex) {
                results[response.choiceIndex] = .correct
            }
        } else {
            if (0..<slotCount).contains(response.choiceIndex) {
                results[response.choiceIndex] = .wrong(correctIndex: response.correctIndex)
            }
            if (0..<slotCount).contains(response.correctIndex) {
                // Правильный слот помечаем как wrong(correctIndex: ownIndex),
                // что во View рендерится как «revealed» (золотой).
                results[response.correctIndex] = .wrong(correctIndex: response.correctIndex)
            }
        }

        let feedback = response.isCorrect
            ? String(localized: "Правильно!")
            : String(localized: "Правильный ответ: \(response.correctWord)")

        let vm = VisualAcousticModels.ChoiceWord.ViewModel(
            choiceResults: results,
            feedbackCorrect: response.isCorrect,
            feedbackText: feedback
        )
        logger.info(
            "presentChoiceWord correct=\(response.isCorrect, privacy: .public) chosen=\(response.choiceIndex, privacy: .public) correctIdx=\(response.correctIndex, privacy: .public)"
        )
        display?.displayChoiceWord(vm)
    }

    // MARK: - NextRound

    func presentNextRound(_ response: VisualAcousticModels.NextRound.Response) {
        let vm = VisualAcousticModels.NextRound.ViewModel(
            hasNextRound: response.hasNextRound,
            nextRoundIndex: response.nextRoundIndex
        )
        display?.displayNextRound(vm)
    }

    // MARK: - Complete

    func presentComplete(_ response: VisualAcousticModels.Complete.Response) {
        let stars = VisualAcousticScoring.stars(for: response.score)
        let pct = Int((response.score * 100).rounded())
        let scoreLabel = String(localized: "Результат: \(pct)%")

        let message: String
        switch stars {
        case 3: message = String(localized: "Превосходно! Все звуки услышал правильно.")
        case 2: message = String(localized: "Отличная работа!")
        case 1: message = String(localized: "Хорошо, но можно ещё лучше.")
        default: message = String(localized: "Попробуем ещё раз?")
        }

        logger.info(
            "presentComplete score=\(response.score, privacy: .public) stars=\(stars, privacy: .public) correct=\(response.correctCount, privacy: .public)/\(response.totalRounds, privacy: .public)"
        )

        let vm = VisualAcousticModels.Complete.ViewModel(
            scoreLabel: scoreLabel,
            starsEarned: stars,
            completionMessage: message,
            finalScore: response.score
        )
        display?.displayComplete(vm)
    }

    // MARK: - Helpers

    /// Прогресс = roundIndex / totalRounds.
    /// До первого раунда — 0, после последнего — 1.
    private static func progressFraction(roundIndex: Int, totalRounds: Int) -> Double {
        guard totalRounds > 0 else { return 0 }
        return min(max(Double(roundIndex) / Double(totalRounds), 0), 1)
    }
}
