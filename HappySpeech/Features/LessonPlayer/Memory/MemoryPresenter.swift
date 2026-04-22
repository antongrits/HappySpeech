import Foundation

// MARK: - MemoryPresentationLogic

@MainActor
protocol MemoryPresentationLogic: AnyObject {
    func presentLoadSession(_ response: MemoryModels.LoadSession.Response)
    func presentSubmitAttempt(_ response: MemoryModels.SubmitAttempt.Response)
}

// MARK: - MemoryPresenter

@MainActor
final class MemoryPresenter: MemoryPresentationLogic {

    weak var viewModel: (any MemoryDisplayLogic)?

    func presentLoadSession(_ response: MemoryModels.LoadSession.Response) {
        let vm = MemoryModels.LoadSession.ViewModel(displayItems: response.items)
        viewModel?.displayLoadSession(vm)
    }

    func presentSubmitAttempt(_ response: MemoryModels.SubmitAttempt.Response) {
        let feedbackText = response.isCorrect ? "Отлично!" : "Попробуй ещё раз"
        let vm = MemoryModels.SubmitAttempt.ViewModel(
            feedbackText: feedbackText,
            isCorrect: response.isCorrect
        )
        viewModel?.displaySubmitAttempt(vm)
    }
}
