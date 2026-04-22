import Foundation

// MARK: - RepeatAfterModelPresentationLogic

@MainActor
protocol RepeatAfterModelPresentationLogic: AnyObject {
    func presentLoadSession(_ response: RepeatAfterModelModels.LoadSession.Response)
    func presentSubmitAttempt(_ response: RepeatAfterModelModels.SubmitAttempt.Response)
}

// MARK: - RepeatAfterModelPresenter

@MainActor
final class RepeatAfterModelPresenter: RepeatAfterModelPresentationLogic {

    weak var viewModel: (any RepeatAfterModelDisplayLogic)?

    func presentLoadSession(_ response: RepeatAfterModelModels.LoadSession.Response) {
        let vm = RepeatAfterModelModels.LoadSession.ViewModel(displayItems: response.items)
        viewModel?.displayLoadSession(vm)
    }

    func presentSubmitAttempt(_ response: RepeatAfterModelModels.SubmitAttempt.Response) {
        let feedbackText = response.isCorrect ? "Отлично!" : "Попробуй ещё раз"
        let vm = RepeatAfterModelModels.SubmitAttempt.ViewModel(
            feedbackText: feedbackText,
            isCorrect: response.isCorrect
        )
        viewModel?.displaySubmitAttempt(vm)
    }
}
