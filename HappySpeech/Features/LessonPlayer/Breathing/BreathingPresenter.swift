import Foundation

// MARK: - BreathingPresentationLogic

@MainActor
protocol BreathingPresentationLogic: AnyObject {
    func presentLoadSession(_ response: BreathingModels.LoadSession.Response)
    func presentSubmitAttempt(_ response: BreathingModels.SubmitAttempt.Response)
}

// MARK: - BreathingPresenter

@MainActor
final class BreathingPresenter: BreathingPresentationLogic {

    weak var viewModel: (any BreathingDisplayLogic)?

    func presentLoadSession(_ response: BreathingModels.LoadSession.Response) {
        let vm = BreathingModels.LoadSession.ViewModel(displayItems: response.items)
        viewModel?.displayLoadSession(vm)
    }

    func presentSubmitAttempt(_ response: BreathingModels.SubmitAttempt.Response) {
        let feedbackText = response.isCorrect ? "Отлично!" : "Попробуй ещё раз"
        let vm = BreathingModels.SubmitAttempt.ViewModel(
            feedbackText: feedbackText,
            isCorrect: response.isCorrect
        )
        viewModel?.displaySubmitAttempt(vm)
    }
}
