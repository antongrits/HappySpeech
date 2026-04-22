import Foundation

// MARK: - MinimalPairsPresentationLogic

@MainActor
protocol MinimalPairsPresentationLogic: AnyObject {
    func presentLoadSession(_ response: MinimalPairsModels.LoadSession.Response)
    func presentSubmitAttempt(_ response: MinimalPairsModels.SubmitAttempt.Response)
}

// MARK: - MinimalPairsPresenter

@MainActor
final class MinimalPairsPresenter: MinimalPairsPresentationLogic {

    weak var viewModel: (any MinimalPairsDisplayLogic)?

    func presentLoadSession(_ response: MinimalPairsModels.LoadSession.Response) {
        let vm = MinimalPairsModels.LoadSession.ViewModel(displayItems: response.items)
        viewModel?.displayLoadSession(vm)
    }

    func presentSubmitAttempt(_ response: MinimalPairsModels.SubmitAttempt.Response) {
        let feedbackText = response.isCorrect ? "Отлично!" : "Попробуй ещё раз"
        let vm = MinimalPairsModels.SubmitAttempt.ViewModel(
            feedbackText: feedbackText,
            isCorrect: response.isCorrect
        )
        viewModel?.displaySubmitAttempt(vm)
    }
}
