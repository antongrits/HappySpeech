import Foundation

// MARK: - PuzzleRevealDisplayLogic

@MainActor
protocol PuzzleRevealDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: PuzzleRevealModels.LoadSession.ViewModel)
    func displaySubmitAttempt(_ viewModel: PuzzleRevealModels.SubmitAttempt.ViewModel)
}
