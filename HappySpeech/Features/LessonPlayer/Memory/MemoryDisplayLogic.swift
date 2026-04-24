import Foundation

// MARK: - MemoryDisplayLogic
//
// Protocol Presenter → View (Display-store). All methods main-actor — write
// в @Observable state.

@MainActor
protocol MemoryDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: MemoryModels.LoadSession.ViewModel)
    func displayFlipCard(_ viewModel: MemoryModels.FlipCard.ViewModel)
    func displayTimerTick(_ viewModel: MemoryModels.TimerTick.ViewModel)
    func displayCompleteSession(_ viewModel: MemoryModels.CompleteSession.ViewModel)
}
