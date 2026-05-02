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
    func displayReplayModel(_ viewModel: RepeatAfterModelModels.ReplayModel.ViewModel)
    func displayHint(_ viewModel: RepeatAfterModelModels.Hint.ViewModel)
    func displaySloMo(_ viewModel: RepeatAfterModelModels.SloMo.ViewModel)
    func displayCompleteSession(_ viewModel: RepeatAfterModelModels.CompleteSession.ViewModel)
}
