import Foundation

// MARK: - ARActivityDisplayLogic

@MainActor
protocol ARActivityDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: ARActivityModels.LoadSession.ViewModel)
    func displaySubmitAttempt(_ viewModel: ARActivityModels.SubmitAttempt.ViewModel)
}
