import Foundation

// MARK: - RhythmDisplayLogic

@MainActor
protocol RhythmDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: RhythmModels.LoadSession.ViewModel)
    func displaySubmitAttempt(_ viewModel: RhythmModels.SubmitAttempt.ViewModel)
}
