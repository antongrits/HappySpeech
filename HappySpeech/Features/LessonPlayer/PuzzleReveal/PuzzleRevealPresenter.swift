import Foundation

// MARK: - PuzzleRevealPresentationLogic

@MainActor
protocol PuzzleRevealPresentationLogic: AnyObject {
    func presentLoadSession(_ response: PuzzleRevealModels.LoadSession.Response)
    func presentSubmitAttempt(_ response: PuzzleRevealModels.SubmitAttempt.Response)
}

// MARK: - PuzzleRevealPresenter

@MainActor
final class PuzzleRevealPresenter: PuzzleRevealPresentationLogic {

    weak var viewModel: (any PuzzleRevealDisplayLogic)?

    func presentLoadSession(_ response: PuzzleRevealModels.LoadSession.Response) {
        let vm = PuzzleRevealModels.LoadSession.ViewModel(displayItems: response.items)
        viewModel?.displayLoadSession(vm)
    }

    func presentSubmitAttempt(_ response: PuzzleRevealModels.SubmitAttempt.Response) {
        let feedbackText = response.isCorrect ? "Отлично!" : "Попробуй ещё раз"
        let vm = PuzzleRevealModels.SubmitAttempt.ViewModel(
            feedbackText: feedbackText,
            isCorrect: response.isCorrect
        )
        viewModel?.displaySubmitAttempt(vm)
    }
}
