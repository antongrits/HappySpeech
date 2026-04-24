import Foundation

// MARK: - MinimalPairsPresentationLogic

@MainActor
protocol MinimalPairsPresentationLogic: AnyObject {
    func presentLoadSession(_ response: MinimalPairsModels.LoadSession.Response)
    func presentStartRound(_ response: MinimalPairsModels.StartRound.Response)
    func presentSelectOption(_ response: MinimalPairsModels.SelectOption.Response)
    func presentCompleteSession(_ response: MinimalPairsModels.CompleteSession.Response)
}

// MARK: - MinimalPairsPresenter
//
// Форматирует доменные Response-структуры в ViewModel со строками,
// готовыми к отрисовке. Все тексты локализованы через String Catalog.

@MainActor
final class MinimalPairsPresenter: MinimalPairsPresentationLogic {

    weak var viewModel: (any MinimalPairsDisplayLogic)?

    // MARK: LoadSession

    func presentLoadSession(_ response: MinimalPairsModels.LoadSession.Response) {
        let greeting = response.childName.isEmpty
            ? String(localized: "Слушай и выбирай!")
            : String(localized: "Привет, \(response.childName)! Слушай и выбирай.")
        let vm = MinimalPairsModels.LoadSession.ViewModel(
            totalRounds: response.rounds.count,
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
            targetWord: response.pair.targetWord
        )
        viewModel?.displayStartRound(vm)
    }

    // MARK: SelectOption

    func presentSelectOption(_ response: MinimalPairsModels.SelectOption.Response) {
        let feedback = response.correct
            ? String(localized: "Молодец! Правильно!")
            : String(localized: "Это «\(response.correctAnswer)». Послушай ещё раз!")
        let vm = MinimalPairsModels.SelectOption.ViewModel(
            correct: response.correct,
            feedbackText: feedback,
            correctAnswer: response.correctAnswer
        )
        viewModel?.displaySelectOption(vm)
    }

    // MARK: CompleteSession

    func presentCompleteSession(_ response: MinimalPairsModels.CompleteSession.Response) {
        let total = max(response.totalRounds, 1)
        let ratio = Double(response.correctCount) / Double(total)
        let stars: Int
        switch ratio {
        case 0.9...:      stars = 3
        case 0.7..<0.9:   stars = 2
        case 0.5..<0.7:   stars = 1
        default:          stars = 0
        }
        let scoreLabel = "\(response.correctCount) / \(response.totalRounds)"
        let message: String
        switch stars {
        case 3: message = String(localized: "Превосходно! Ты отлично различаешь звуки.")
        case 2: message = String(localized: "Здорово! Почти всё правильно.")
        case 1: message = String(localized: "Хорошая работа! Продолжай тренироваться.")
        default: message = String(localized: "Давай попробуем ещё раз — у тебя получится!")
        }
        let vm = MinimalPairsModels.CompleteSession.ViewModel(
            starsEarned: stars,
            scoreLabel: scoreLabel,
            message: message
        )
        viewModel?.displayCompleteSession(vm)
    }
}
