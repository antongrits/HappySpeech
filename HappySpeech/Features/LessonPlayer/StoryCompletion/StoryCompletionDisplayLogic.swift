import Foundation

// MARK: - StoryCompletionDisplayLogic

@MainActor
protocol StoryCompletionDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: StoryCompletionModels.LoadSession.ViewModel)
    func displaySubmitAttempt(_ viewModel: StoryCompletionModels.SubmitAttempt.ViewModel)
}
