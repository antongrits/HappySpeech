import Foundation

// MARK: - DragAndMatchPresentationLogic

@MainActor
protocol DragAndMatchPresentationLogic: AnyObject {
    func presentLoadSession(_ response: DragAndMatchModels.LoadSession.Response)
    func presentSubmitAttempt(_ response: DragAndMatchModels.SubmitAttempt.Response)
}

// MARK: - DragAndMatchPresenter

@MainActor
final class DragAndMatchPresenter: DragAndMatchPresentationLogic {

    weak var viewModel: (any DragAndMatchDisplayLogic)?

    func presentLoadSession(_ response: DragAndMatchModels.LoadSession.Response) {
        let vm = DragAndMatchModels.LoadSession.ViewModel(displayItems: response.items)
        viewModel?.displayLoadSession(vm)
    }

    func presentSubmitAttempt(_ response: DragAndMatchModels.SubmitAttempt.Response) {
        let feedbackText = response.isCorrect ? "Отлично!" : "Попробуй ещё раз"
        let vm = DragAndMatchModels.SubmitAttempt.ViewModel(
            feedbackText: feedbackText,
            isCorrect: response.isCorrect
        )
        viewModel?.displaySubmitAttempt(vm)
    }
}
