import Foundation

// MARK: - BingoDisplayLogic

@MainActor
protocol BingoDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: BingoModels.LoadSession.ViewModel)
    func displaySubmitAttempt(_ viewModel: BingoModels.SubmitAttempt.ViewModel)
}
