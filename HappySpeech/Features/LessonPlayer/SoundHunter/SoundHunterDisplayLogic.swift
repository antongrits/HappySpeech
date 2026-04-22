import Foundation

// MARK: - SoundHunterDisplayLogic

@MainActor
protocol SoundHunterDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: SoundHunterModels.LoadSession.ViewModel)
    func displaySubmitAttempt(_ viewModel: SoundHunterModels.SubmitAttempt.ViewModel)
}
