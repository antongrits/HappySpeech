import Foundation

// MARK: - ARActivityPresentationLogic

@MainActor
protocol ARActivityPresentationLogic: AnyObject {
    func presentLoadSession(_ response: ARActivityModels.LoadSession.Response)
    func presentSubmitAttempt(_ response: ARActivityModels.SubmitAttempt.Response)
}

// MARK: - ARActivityPresenter

@MainActor
final class ARActivityPresenter: ARActivityPresentationLogic {

    weak var viewModel: (any ARActivityDisplayLogic)?

    func presentLoadSession(_ response: ARActivityModels.LoadSession.Response) {
        let vm = ARActivityModels.LoadSession.ViewModel(displayItems: response.items)
        viewModel?.displayLoadSession(vm)
    }

    func presentSubmitAttempt(_ response: ARActivityModels.SubmitAttempt.Response) {
        let feedbackText = response.isCorrect ? "Отлично!" : "Попробуй ещё раз"
        let vm = ARActivityModels.SubmitAttempt.ViewModel(
            feedbackText: feedbackText,
            isCorrect: response.isCorrect
        )
        viewModel?.displaySubmitAttempt(vm)
    }
}
