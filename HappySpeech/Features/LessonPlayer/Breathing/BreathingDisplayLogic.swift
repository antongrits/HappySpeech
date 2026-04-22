import Foundation

// MARK: - BreathingDisplayLogic

@MainActor
protocol BreathingDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: BreathingModels.LoadSession.ViewModel)
    func displaySubmitAttempt(_ viewModel: BreathingModels.SubmitAttempt.ViewModel)
}
