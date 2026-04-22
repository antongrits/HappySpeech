import Foundation

// MARK: - VisualAcousticPresentationLogic

@MainActor
protocol VisualAcousticPresentationLogic: AnyObject {
    func presentLoadSession(_ response: VisualAcousticModels.LoadSession.Response)
    func presentSubmitAttempt(_ response: VisualAcousticModels.SubmitAttempt.Response)
}

// MARK: - VisualAcousticPresenter

@MainActor
final class VisualAcousticPresenter: VisualAcousticPresentationLogic {

    weak var viewModel: (any VisualAcousticDisplayLogic)?

    func presentLoadSession(_ response: VisualAcousticModels.LoadSession.Response) {
        let vm = VisualAcousticModels.LoadSession.ViewModel(displayItems: response.items)
        viewModel?.displayLoadSession(vm)
    }

    func presentSubmitAttempt(_ response: VisualAcousticModels.SubmitAttempt.Response) {
        let feedbackText = response.isCorrect ? "Отлично!" : "Попробуй ещё раз"
        let vm = VisualAcousticModels.SubmitAttempt.ViewModel(
            feedbackText: feedbackText,
            isCorrect: response.isCorrect
        )
        viewModel?.displaySubmitAttempt(vm)
    }
}
