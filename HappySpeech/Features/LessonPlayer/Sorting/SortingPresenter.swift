import Foundation

// MARK: - SortingPresentationLogic

@MainActor
protocol SortingPresentationLogic: AnyObject {
    func presentLoadSession(_ response: SortingModels.LoadSession.Response)
    func presentClassifyWord(_ response: SortingModels.ClassifyWord.Response)
    func presentHint(_ response: SortingModels.RequestHint.Response)
    func presentAutoPlace(_ response: SortingModels.AutoPlace.Response)
    func presentStreakBonus(_ response: SortingModels.StreakBonus.Response)
    func presentTimerTick(_ response: SortingModels.TimerTick.Response)
    func presentCompleteSession(_ response: SortingModels.CompleteSession.Response)
}

// MARK: - SortingPresenter
//
// Конвертирует доменные Response в ViewModel с локализованными строками,
// цветами таймера, подсказками и формулой звёзд по итоговому скору.

@MainActor
final class SortingPresenter: SortingPresentationLogic {

    weak var viewModel: (any SortingDisplayLogic)?

    // MARK: LoadSession

    func presentLoadSession(_ response: SortingModels.LoadSession.Response) {
        let greeting = response.childName.isEmpty
            ? response.taskDescription
            : String(localized: "Привет, \(response.childName)! \(response.taskDescription)")
        let vm = SortingModels.LoadSession.ViewModel(
            setTitle: response.setTitle,
            taskType: response.taskType,
            taskDescription: response.taskDescription,
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
                : response.feedback
        } else {
            feedback = response.feedback
        }
        let vm = SortingModels.ClassifyWord.ViewModel(
            correct: response.correct,
            wordId: response.wordId,
            categoryId: response.categoryId,
            feedbackText: feedback,
            streakBadgeVisible: response.streakBonusTriggered,
            remainingCount: response.remainingCount
        )
        viewModel?.displayClassifyWord(vm)
    }

    // MARK: RequestHint

    func presentHint(_ response: SortingModels.RequestHint.Response) {
        let hintText: String
        switch response.hintLevel {
        case 1:
            hintText = response.hintText
        case 2:
            hintText = response.hintText
        default:
            hintText = String(localized: "Я помогаю — кладу слово на место")
        }
        let vm = SortingModels.RequestHint.ViewModel(
            wordId: response.wordId,
            hintLevel: response.hintLevel,
            highlightCategoryId: response.highlightCategoryId,
            hintText: hintText,
            isAutoPlace: response.isAutoPlace
        )
        viewModel?.displayHint(vm)
    }

    // MARK: AutoPlace

    func presentAutoPlace(_ response: SortingModels.AutoPlace.Response) {
        let vm = SortingModels.AutoPlace.ViewModel(
            wordId: response.wordId,
            categoryId: response.categoryId
        )
        viewModel?.displayAutoPlace(vm)
    }

    // MARK: StreakBonus

    func presentStreakBonus(_ response: SortingModels.StreakBonus.Response) {
        let bonusText: String
        switch response.streak {
        case 3:  bonusText = String(localized: "Три подряд! Отлично!")
        case 4:  bonusText = String(localized: "Четыре подряд! Невероятно!")
        case 5:  bonusText = String(localized: "Пять подряд! Ты супер!")
        default: bonusText = String(localized: "Серия ×\(response.streak)! Продолжай!")
        }
        let vm = SortingModels.StreakBonus.ViewModel(
            streak: response.streak,
            bonusText: bonusText
        )
        viewModel?.displayStreakBonus(vm)
    }

    // MARK: TimerTick

    func presentTimerTick(_ response: SortingModels.TimerTick.Response) {
        let minutes = response.remaining / 60
        let seconds = response.remaining % 60
        let label = String(format: "%02d:%02d", minutes, seconds)
        let color: String
        switch response.remaining {
        case 0:       color = "red"
        case 1...15:  color = "red"
        case 16...30: color = "orange"
        default:      color = "green"
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
        case (_, .autoDistributed):
            message = String(localized: "Я помог разложить. Попробуем ещё раз?")
        default:
            message = String(localized: "Давай попробуем ещё раз — у тебя получится!")
        }
        let vm = SortingModels.CompleteSession.ViewModel(
            starsEarned: stars,
            scoreLabel: scoreLabel,
            message: message,
            finalScore: score,
            categoryBreakdown: response.categoryBreakdown,
            bestCategoryTitle: response.bestCategoryTitle,
            worstCategoryTitle: response.worstCategoryTitle,
            autoPlacedCount: response.autoPlacedCount
        )
        viewModel?.displayCompleteSession(vm)
    }
}
