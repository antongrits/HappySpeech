import Foundation

// MARK: - MinimalPairsPresentationLogic

@MainActor
protocol MinimalPairsPresentationLogic: AnyObject {
    func presentLoadSession(_ response: MinimalPairsModels.LoadSession.Response)
    func presentStartRound(_ response: MinimalPairsModels.StartRound.Response)
    func presentSelectOption(_ response: MinimalPairsModels.SelectOption.Response)
    func presentReplayWord(_ response: MinimalPairsModels.ReplayWord.Response)
    func presentHint(_ response: MinimalPairsModels.RequestHint.Response)
    func presentBonusRoundAdded(_ response: MinimalPairsModels.BonusRoundAdded.Response)
    func presentCompleteSession(_ response: MinimalPairsModels.CompleteSession.Response)
}

// MARK: - MinimalPairsPresenter
//
// Форматирует доменные Response-структуры в ViewModel со строками,
// готовыми к отрисовке. Все тексты локализованы через String(localized:).

@MainActor
final class MinimalPairsPresenter: MinimalPairsPresentationLogic {

    weak var viewModel: (any MinimalPairsDisplayLogic)?

    // MARK: LoadSession

    func presentLoadSession(_ response: MinimalPairsModels.LoadSession.Response) {
        let greeting = response.childName.isEmpty
            ? String(localized: "Слушай и выбирай!")
            : String(localized: "Привет, \(response.childName)! Слушай и выбирай.")
        let vm = MinimalPairsModels.LoadSession.ViewModel(
            totalRounds: response.totalRounds,
            greeting: greeting
        )
        viewModel?.displayLoadSession(vm)
    }

    // MARK: StartRound

    func presentStartRound(_ response: MinimalPairsModels.StartRound.Response) {
        let progress = "\(response.roundNumber) / \(response.total)"
        let prompt = String(localized: "Покажи картинку: «\(response.pair.targetWord)»")
        let vm = MinimalPairsModels.StartRound.ViewModel(
            pair: response.pair,
            progressLabel: progress,
            promptText: prompt,
            targetWord: response.pair.targetWord,
            hintsAvailable: response.hintsAvailable
        )
        viewModel?.displayStartRound(vm)
    }

    // MARK: SelectOption

    func presentSelectOption(_ response: MinimalPairsModels.SelectOption.Response) {
        let feedback: String
        if response.isStreakBonus {
            feedback = String(localized: "Потрясающе! Пять подряд!")
        } else if response.correct {
            feedback = String(localized: "Молодец! Правильно!")
        } else {
            feedback = String(localized: "Это «\(response.correctAnswer)». Послушай ещё раз!")
        }

        let streakLabel: String? = response.streakCount >= 3
            ? String(localized: "Серия: \(response.streakCount)")
            : nil

        let vm = MinimalPairsModels.SelectOption.ViewModel(
            correct: response.correct,
            feedbackText: feedback,
            correctAnswer: response.correctAnswer,
            isStreakBonus: response.isStreakBonus,
            streakLabel: streakLabel
        )
        viewModel?.displaySelectOption(vm)
    }

    // MARK: ReplayWord

    func presentReplayWord(_ response: MinimalPairsModels.ReplayWord.Response) {
        let toast: String? = response.capReached
            ? String(localized: "Повторов больше нет")
            : nil
        let vm = MinimalPairsModels.ReplayWord.ViewModel(
            replaysRemaining: response.replaysRemaining,
            capReached: response.capReached,
            toastMessage: toast
        )
        viewModel?.displayReplayWord(vm)
    }

    // MARK: RequestHint

    func presentHint(_ response: MinimalPairsModels.RequestHint.Response) {
        let toast: String
        if response.capReached {
            toast = String(localized: "Подсказок больше нет")
        } else {
            switch response.level {
            case .highlight:
                toast = String(localized: "Смотри внимательно!")
            case .voiceClarification:
                toast = String(localized: "Подсказка: слушай звук")
            }
        }
        let vm = MinimalPairsModels.RequestHint.ViewModel(
            level: response.level,
            highlightDuration: response.highlightDuration,
            toastMessage: toast,
            hintsRemaining: response.hintsRemaining,
            capReached: response.capReached
        )
        viewModel?.displayHint(vm)
    }

    // MARK: BonusRoundAdded

    func presentBonusRoundAdded(_ response: MinimalPairsModels.BonusRoundAdded.Response) {
        let vm = MinimalPairsModels.BonusRoundAdded.ViewModel(
            toastMessage: response.message,
            totalRounds: response.totalRounds
        )
        viewModel?.displayBonusRoundAdded(vm)
    }

    // MARK: CompleteSession

    func presentCompleteSession(_ response: MinimalPairsModels.CompleteSession.Response) {
        let total = max(response.totalRounds, 1)
        let ratio = Double(response.correctCount) / Double(total)
        let stars: Int
        switch ratio {
        case 0.9...:    stars = 3
        case 0.7..<0.9: stars = 2
        case 0.5..<0.7: stars = 1
        default:        stars = 0
        }
        let scoreLabel = "\(response.correctCount) / \(response.totalRounds)"
        let message: String
        switch stars {
        case 3: message = String(localized: "Превосходно! Ты отлично различаешь звуки.")
        case 2: message = String(localized: "Здорово! Почти всё правильно.")
        case 1: message = String(localized: "Хорошая работа! Продолжай тренироваться.")
        default: message = String(localized: "Давай попробуем ещё раз — у тебя получится!")
        }

        let summary = response.pairAccuracy
            .sorted { $0.value < $1.value }
            .map { key, value in
                MinimalPairsModels.PairSummaryItem(
                    id: key,
                    contrast: key,
                    accuracyPercent: Int(value * 100),
                    accuracyLabel: "\(Int(value * 100))%"
                )
            }

        let vm = MinimalPairsModels.CompleteSession.ViewModel(
            starsEarned: stars,
            scoreLabel: scoreLabel,
            message: message,
            pairSummary: summary
        )
        viewModel?.displayCompleteSession(vm)
    }
}
