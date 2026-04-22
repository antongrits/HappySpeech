import Foundation

// MARK: - ArticulationImitationPresentationLogic

@MainActor
protocol ArticulationImitationPresentationLogic: AnyObject {
    func presentLoadSession(_ response: ArticulationImitationModels.LoadSession.Response)
    func presentSubmitAttempt(_ response: ArticulationImitationModels.SubmitAttempt.Response)
}

// MARK: - ArticulationImitationPresenter

@MainActor
final class ArticulationImitationPresenter: ArticulationImitationPresentationLogic {

    weak var viewModel: (any ArticulationImitationDisplayLogic)?

    func presentLoadSession(_ response: ArticulationImitationModels.LoadSession.Response) {
        let vm = ArticulationImitationModels.LoadSession.ViewModel(displayItems: response.items)
        viewModel?.displayLoadSession(vm)
    }

    func presentSubmitAttempt(_ response: ArticulationImitationModels.SubmitAttempt.Response) {
        let feedbackText = response.isCorrect ? "Отлично!" : "Попробуй ещё раз"
        let vm = ArticulationImitationModels.SubmitAttempt.ViewModel(
            feedbackText: feedbackText,
            isCorrect: response.isCorrect
        )
        viewModel?.displaySubmitAttempt(vm)
    }
}
