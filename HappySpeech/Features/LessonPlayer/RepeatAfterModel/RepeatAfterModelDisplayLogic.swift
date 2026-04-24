import Foundation

// MARK: - RepeatAfterModelDisplayLogic
//
// Реализуется `RepeatAfterModelStoreBridge`, который ретранслирует
// ViewModel-обновления в `RepeatAfterModelDisplay` (@Observable store).

@MainActor
protocol RepeatAfterModelDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: RepeatAfterModelModels.LoadSession.ViewModel)
    func displayStartWord(_ viewModel: RepeatAfterModelModels.StartWord.ViewModel)
    func displayRecordAttempt(_ viewModel: RepeatAfterModelModels.RecordAttempt.ViewModel)
    func displayEvaluateAttempt(_ viewModel: RepeatAfterModelModels.EvaluateAttempt.ViewModel)
    func displayCompleteSession(_ viewModel: RepeatAfterModelModels.CompleteSession.ViewModel)
}
