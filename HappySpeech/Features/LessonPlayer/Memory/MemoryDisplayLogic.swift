import Foundation

// MARK: - MemoryDisplayLogic

@MainActor
protocol MemoryDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: MemoryModels.LoadSession.ViewModel)
    func displaySubmitAttempt(_ viewModel: MemoryModels.SubmitAttempt.ViewModel)
}
