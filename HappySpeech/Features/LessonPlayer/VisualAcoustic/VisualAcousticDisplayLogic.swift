import Foundation

// MARK: - VisualAcousticDisplayLogic

@MainActor
protocol VisualAcousticDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: VisualAcousticModels.LoadSession.ViewModel)
    func displaySubmitAttempt(_ viewModel: VisualAcousticModels.SubmitAttempt.ViewModel)
}
