import Foundation

// MARK: - RepeatAfterModelDisplayLogic

@MainActor
protocol RepeatAfterModelDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: RepeatAfterModelModels.LoadSession.ViewModel)
    func displaySubmitAttempt(_ viewModel: RepeatAfterModelModels.SubmitAttempt.ViewModel)
}
