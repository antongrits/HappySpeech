import Foundation

// MARK: - StoryCompletionPresentationLogic

@MainActor
protocol StoryCompletionPresentationLogic: AnyObject {
    func presentLoadSession(_ response: StoryCompletionModels.LoadSession.Response)
    func presentSubmitAttempt(_ response: StoryCompletionModels.SubmitAttempt.Response)
}

// MARK: - StoryCompletionPresenter

@MainActor
final class StoryCompletionPresenter: StoryCompletionPresentationLogic {

    weak var viewModel: (any StoryCompletionDisplayLogic)?

    func presentLoadSession(_ response: StoryCompletionModels.LoadSession.Response) {
        let vm = StoryCompletionModels.LoadSession.ViewModel(displayItems: response.items)
        viewModel?.displayLoadSession(vm)
    }

    func presentSubmitAttempt(_ response: StoryCompletionModels.SubmitAttempt.Response) {
        let feedbackText = response.isCorrect ? "Отлично!" : "Попробуй ещё раз"
        let vm = StoryCompletionModels.SubmitAttempt.ViewModel(
            feedbackText: feedbackText,
            isCorrect: response.isCorrect
        )
        viewModel?.displaySubmitAttempt(vm)
    }
}
