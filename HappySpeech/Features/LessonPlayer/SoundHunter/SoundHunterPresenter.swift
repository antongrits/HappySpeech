import Foundation

// MARK: - SoundHunterPresentationLogic

@MainActor
protocol SoundHunterPresentationLogic: AnyObject {
    func presentLoadSession(_ response: SoundHunterModels.LoadSession.Response)
    func presentSubmitAttempt(_ response: SoundHunterModels.SubmitAttempt.Response)
}

// MARK: - SoundHunterPresenter

@MainActor
final class SoundHunterPresenter: SoundHunterPresentationLogic {

    weak var viewModel: (any SoundHunterDisplayLogic)?

    func presentLoadSession(_ response: SoundHunterModels.LoadSession.Response) {
        let vm = SoundHunterModels.LoadSession.ViewModel(displayItems: response.items)
        viewModel?.displayLoadSession(vm)
    }

    func presentSubmitAttempt(_ response: SoundHunterModels.SubmitAttempt.Response) {
        let feedbackText = response.isCorrect ? "Отлично!" : "Попробуй ещё раз"
        let vm = SoundHunterModels.SubmitAttempt.ViewModel(
            feedbackText: feedbackText,
            isCorrect: response.isCorrect
        )
        viewModel?.displaySubmitAttempt(vm)
    }
}
