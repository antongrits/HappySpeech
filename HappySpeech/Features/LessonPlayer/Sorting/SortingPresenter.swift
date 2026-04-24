import Foundation

// MARK: - SortingPresentationLogic

@MainActor
protocol SortingPresentationLogic: AnyObject {
    func presentLoadSession(_ response: SortingModels.LoadSession.Response)
    func presentClassifyWord(_ response: SortingModels.ClassifyWord.Response)
    func presentTimerTick(_ response: SortingModels.TimerTick.Response)
    func presentCompleteSession(_ response: SortingModels.CompleteSession.Response)
}

// MARK: - SortingPresenter
//
// Конвертирует доменные Response в ViewModel с локализованными строками,
// цветами таймера и формулой звёзд по итоговому скору.

@MainActor
final class SortingPresenter: SortingPresentationLogic {

    weak var viewModel: (any SortingDisplayLogic)?

    // MARK: LoadSession

    func presentLoadSession(_ response: SortingModels.LoadSession.Response) {
        let greeting = response.childName.isEmpty
            ? String(localized: "Разложи слова по категориям!")
            : String(localized: "Привет, \(response.childName)! Разложи слова.")
        let vm = SortingModels.LoadSession.ViewModel(
            setTitle: response.setTitle,
            words: response.words,
            categories: response.categories,
            greeting: greeting,
            timeLimit: response.timeLimit
        )
        viewModel?.displayLoadSession(vm)
    }

    // MARK: ClassifyWord

    func presentClassifyWord(_ response: SortingModels.ClassifyWord.Response) {
        let feedback: String
        if response.correct {
            feedback = response.streakBonusTriggered
                ? String(localized: "Вот это серия!")
                : String(localized: "Верно!")
        } else {
            feedback = String(localized: "Не совсем. Идём дальше.")
        }
        let vm = SortingModels.ClassifyWord.ViewModel(
            correct: response.correct,
            wordId: response.wordId,
            feedbackText: feedback,
            streakBadgeVisible: response.streakBonusTriggered
        )
        viewModel?.displayClassifyWord(vm)
    }

    // MARK: TimerTick

    func presentTimerTick(_ response: SortingModels.TimerTick.Response) {
        let minutes = response.remaining / 60
        let seconds = response.remaining % 60
        let label = String(format: "%02d:%02d", minutes, seconds)
        let color: String
        switch response.remaining {
        case 0:      color = "red"
        case 1...15: color = "red"
        case 16...30: color = "orange"
        default:     color = "green"
        }
        let vm = SortingModels.TimerTick.ViewModel(
            timerLabel: label,
            timerColor: color,
            expired: response.expired
        )
        viewModel?.displayTimerTick(vm)
    }

    // MARK: CompleteSession

    func presentCompleteSession(_ response: SortingModels.CompleteSession.Response) {
        let score = response.finalScore
        let stars: Int
        switch score {
        case 0.90...:     stars = 3
        case 0.70..<0.90: stars = 2
        case 0.50..<0.70: stars = 1
        default:          stars = 0
        }
        let scoreLabel = "\(response.correctCount) / \(response.total)"
        let message: String
        switch (stars, response.reason) {
        case (3, _):
            message = String(localized: "Превосходно! Ты разложил всё правильно.")
        case (2, _):
            message = String(localized: "Отлично! Почти всё верно.")
        case (1, _):
            message = String(localized: "Хорошо! Продолжай тренироваться.")
        case (_, .timeExpired):
            message = String(localized: "Время вышло — попробуй ещё раз!")
        default:
            message = String(localized: "Давай попробуем ещё раз — у тебя получится!")
        }
        let vm = SortingModels.CompleteSession.ViewModel(
            starsEarned: stars,
            scoreLabel: scoreLabel,
            message: message,
            finalScore: score
        )
        viewModel?.displayCompleteSession(vm)
    }
}
