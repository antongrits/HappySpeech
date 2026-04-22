import Foundation

// MARK: - SortingDisplayLogic

@MainActor
protocol SortingDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: SortingModels.LoadSession.ViewModel)
    func displaySubmitAttempt(_ viewModel: SortingModels.SubmitAttempt.ViewModel)
}
