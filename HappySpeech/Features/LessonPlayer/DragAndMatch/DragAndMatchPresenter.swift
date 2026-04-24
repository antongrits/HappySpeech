import Foundation

// MARK: - DragAndMatchPresentationLogic

@MainActor
protocol DragAndMatchPresentationLogic: AnyObject {
    func presentLoadSession(_ response: DragAndMatchModels.LoadSession.Response)
    func presentDropWord(_ response: DragAndMatchModels.DropWord.Response)
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
        let vm = DragAndMatchModels.LoadSession.ViewModel(
            words: response.words,
            buckets: response.buckets,
            greeting: greeting
        )
        viewModel?.displayLoadSession(vm)
    }

    // MARK: DropWord

    func presentDropWord(_ response: DragAndMatchModels.DropWord.Response) {
        let feedback = response.correct
            ? String(localized: "Верно!")
            : String(localized: "Попробуй другую корзину.")
        let vm = DragAndMatchModels.DropWord.ViewModel(
            correct: response.correct,
            wordId: response.wordId,
            feedbackText: feedback
        )
        viewModel?.displayDropWord(vm)
    }

    // MARK: CompleteSession

    func presentCompleteSession(_ response: DragAndMatchModels.CompleteSession.Response) {
        let total = max(response.totalWords, 1)
        let ratio = Double(response.correctCount) / Double(total)
        let stars: Int
        switch ratio {
        case 0.9...:      stars = 3
        case 0.7..<0.9:   stars = 2
        case 0.5..<0.7:   stars = 1
        default:          stars = 0
        }
        let scoreLabel = "\(response.correctCount) / \(response.totalWords)"
        let message: String
        switch stars {
        case 3: message = String(localized: "Превосходно! Все слова на своих местах.")
        case 2: message = String(localized: "Отлично! Почти все правильно.")
        case 1: message = String(localized: "Хорошо! Продолжай тренироваться.")
        default: message = String(localized: "Давай попробуем ещё раз — у тебя получится!")
        }
        let vm = DragAndMatchModels.CompleteSession.ViewModel(
            starsEarned: stars,
            scoreLabel: scoreLabel,
            message: message
        )
        viewModel?.displayCompleteSession(vm)
    }
}
