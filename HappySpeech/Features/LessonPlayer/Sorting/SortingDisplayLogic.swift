import Foundation

// MARK: - SortingDisplayLogic
//
// Протокол Presenter → View (Display-store). Все методы main-actor — пишут
// в @Observable state.

@MainActor
protocol SortingDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: SortingModels.LoadSession.ViewModel)
    func displayClassifyWord(_ viewModel: SortingModels.ClassifyWord.ViewModel)
    func displayTimerTick(_ viewModel: SortingModels.TimerTick.ViewModel)
    func displayCompleteSession(_ viewModel: SortingModels.CompleteSession.ViewModel)
}
