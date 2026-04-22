import Foundation

// MARK: - RhythmPresentationLogic

@MainActor
protocol RhythmPresentationLogic: AnyObject {
    func presentLoadSession(_ response: RhythmModels.LoadSession.Response)
    func presentSubmitAttempt(_ response: RhythmModels.SubmitAttempt.Response)
}

// MARK: - RhythmPresenter

@MainActor
final class RhythmPresenter: RhythmPresentationLogic {

    weak var viewModel: (any RhythmDisplayLogic)?

    func presentLoadSession(_ response: RhythmModels.LoadSession.Response) {
        let vm = RhythmModels.LoadSession.ViewModel(displayItems: response.items)
        viewModel?.displayLoadSession(vm)
    }

    func presentSubmitAttempt(_ response: RhythmModels.SubmitAttempt.Response) {
        let feedbackText = response.isCorrect ? "Отлично!" : "Попробуй ещё раз"
        let vm = RhythmModels.SubmitAttempt.ViewModel(
            feedbackText: feedbackText,
            isCorrect: response.isCorrect
        )
        viewModel?.displaySubmitAttempt(vm)
    }
}
