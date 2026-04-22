import Foundation

// MARK: - SortingPresentationLogic

@MainActor
protocol SortingPresentationLogic: AnyObject {
    func presentLoadSession(_ response: SortingModels.LoadSession.Response)
    func presentSubmitAttempt(_ response: SortingModels.SubmitAttempt.Response)
}

// MARK: - SortingPresenter

@MainActor
final class SortingPresenter: SortingPresentationLogic {

    weak var viewModel: (any SortingDisplayLogic)?

    func presentLoadSession(_ response: SortingModels.LoadSession.Response) {
        let vm = SortingModels.LoadSession.ViewModel(displayItems: response.items)
        viewModel?.displayLoadSession(vm)
    }

    func presentSubmitAttempt(_ response: SortingModels.SubmitAttempt.Response) {
        let feedbackText = response.isCorrect ? "Отлично!" : "Попробуй ещё раз"
        let vm = SortingModels.SubmitAttempt.ViewModel(
            feedbackText: feedbackText,
            isCorrect: response.isCorrect
        )
        viewModel?.displaySubmitAttempt(vm)
    }
}
