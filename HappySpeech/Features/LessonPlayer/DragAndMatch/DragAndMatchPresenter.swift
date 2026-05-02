import Foundation

// MARK: - DragAndMatchPresentationLogic

@MainActor
protocol DragAndMatchPresentationLogic: AnyObject {
    func presentLoadSession(_ response: DragAndMatchModels.LoadSession.Response)
    func presentDropWord(_ response: DragAndMatchModels.DropWord.Response)
    func presentHint(_ response: DragAndMatchModels.RequestHint.Response)
    func presentCompleteRound(_ response: DragAndMatchModels.CompleteRound.Response)
    func presentCompleteSession(_ response: DragAndMatchModels.CompleteSession.Response)
}

// MARK: - DragAndMatchPresenter
//
// Конвертирует доменные Response в ViewModel с локализованными строками.

@MainActor
final class DragAndMatchPresenter: DragAndMatchPresentationLogic {

    weak var viewModel: (any DragAndMatchDisplayLogic)?

    // MARK: LoadSession

    func presentLoadSession(_ response: DragAndMatchModels.LoadSession.Response) {
        let greeting = response.childName.isEmpty
            ? String(localized: "Разложи слова по корзинам!")
            : String(localized: "Привет, \(response.childName)! Разложи слова.")
        let roundLabel = String(
            localized: "Раунд \(response.roundIndex + 1) из \(response.totalRounds)"
        )
        let pairLabel = response.confusedPair.map {
            String(localized: "Различаем звуки \($0.displayLabel)")
        }
        let vm = DragAndMatchModels.LoadSession.ViewModel(
            words: response.words,
            buckets: response.buckets,
            greeting: greeting,
            roundLabel: roundLabel,
            confusedPairLabel: pairLabel
        )
        viewModel?.displayLoadSession(vm)
    }

    // MARK: DropWord

    func presentDropWord(_ response: DragAndMatchModels.DropWord.Response) {
        let feedback: String
        if response.correct {
            feedback = response.isStreakBonus
                ? String(localized: "Серия! Отлично!")
                : String(localized: "Верно!")
        } else {
            feedback = String(localized: "Попробуй другую корзину.")
        }
        let streakLabel: String? = response.isStreakBonus
            ? String(localized: "Серия \(response.streakCount)!")
            : nil
        let vm = DragAndMatchModels.DropWord.ViewModel(
            correct: response.correct,
            wordId: response.wordId,
            feedbackText: feedback,
            showStreakBonus: response.isStreakBonus,
            streakLabel: streakLabel,
            hintBucketId: response.hintBucketId
        )
        viewModel?.displayDropWord(vm)
    }

    // MARK: RequestHint

    func presentHint(_ response: DragAndMatchModels.RequestHint.Response) {
        let remainingLabel: String
        switch response.hintsRemaining {
        case 0:
            remainingLabel = String(localized: "Подсказки закончились")
        case 1:
            remainingLabel = String(localized: "Осталась 1 подсказка")
        default:
            remainingLabel = String(
                localized: "Осталось подсказок: \(response.hintsRemaining)"
            )
        }
        let vm = DragAndMatchModels.RequestHint.ViewModel(
            level: response.level,
            targetBucketId: response.targetBucketId,
            voicePromptText: response.voicePromptText,
            autoSolvedWordId: response.autoSolvedWordId,
            autoSolvedBucketId: response.autoSolvedBucketId,
            hintsRemainingLabel: remainingLabel
        )
        viewModel?.displayHint(vm)
    }

    // MARK: CompleteRound

    func presentCompleteRound(_ response: DragAndMatchModels.CompleteRound.Response) {
        let stats = response.stats
        let accuracyLabel = String(
            localized: "Точность: \(Int(stats.accuracy * 100))%"
        )
        let hintsLabel: String
        switch stats.hintsUsed {
        case 0:
            hintsLabel = String(localized: "Без подсказок!")
        case 1:
            hintsLabel = String(localized: "1 подсказка")
        default:
            hintsLabel = String(localized: "Подсказок: \(stats.hintsUsed)")
        }
        let durationLabel = formatDuration(stats.durationSeconds)
        let ctaLabel = response.hasNextRound
            ? String(localized: "Следующий раунд")
            : String(localized: "Посмотреть итог")
        let vm = DragAndMatchModels.CompleteRound.ViewModel(
            accuracyLabel: accuracyLabel,
            hintsLabel: hintsLabel,
            durationLabel: durationLabel,
            hasNextRound: response.hasNextRound,
            ctaLabel: ctaLabel
        )
        viewModel?.displayCompleteRound(vm)
    }

    // MARK: CompleteSession

    func presentCompleteSession(_ response: DragAndMatchModels.CompleteSession.Response) {
        let total = max(response.totalWords, 1)
        let ratio = Double(response.correctCount) / Double(total)
        let stars: Int
        switch ratio {
        case 0.9...:     stars = 3
        case 0.7..<0.9:  stars = 2
        case 0.5..<0.7:  stars = 1
        default:         stars = 0
        }
        let scoreLabel = "\(response.correctCount) / \(response.totalWords)"
        let message: String
        switch stars {
        case 3:  message = String(localized: "Превосходно! Все слова на своих местах.")
        case 2:  message = String(localized: "Отлично! Почти все правильно.")
        case 1:  message = String(localized: "Хорошо! Продолжай тренироваться.")
        default: message = String(localized: "Давай попробуем ещё раз — у тебя получится!")
        }
        let hintsUsedLabel: String
        switch response.totalHintsUsed {
        case 0:  hintsUsedLabel = String(localized: "Подсказок не использовано")
        case 1:  hintsUsedLabel = String(localized: "Использована 1 подсказка")
        default: hintsUsedLabel = String(
            localized: "Использовано подсказок: \(response.totalHintsUsed)"
        )
        }
        let vm = DragAndMatchModels.CompleteSession.ViewModel(
            starsEarned: stars,
            scoreLabel: scoreLabel,
            message: message,
            accuracyPercent: "\(Int(ratio * 100))%",
            hintsUsedLabel: hintsUsedLabel,
            durationLabel: formatDuration(response.totalDurationSeconds)
        )
        viewModel?.displayCompleteSession(vm)
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let minutes = total / 60
        let secs = total % 60
        if minutes > 0 {
            return String(localized: "\(minutes) мин \(secs) сек")
        }
        return String(localized: "\(secs) сек")
    }
}
