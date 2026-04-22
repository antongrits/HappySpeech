import Foundation

// MARK: - MinimalPairsDisplayLogic

@MainActor
protocol MinimalPairsDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: MinimalPairsModels.LoadSession.ViewModel)
    func displaySubmitAttempt(_ viewModel: MinimalPairsModels.SubmitAttempt.ViewModel)
}
