import Foundation

// MARK: - ArticulationImitationDisplayLogic

@MainActor
protocol ArticulationImitationDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: ArticulationImitationModels.LoadSession.ViewModel)
    func displaySubmitAttempt(_ viewModel: ArticulationImitationModels.SubmitAttempt.ViewModel)
}
