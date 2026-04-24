import Foundation

// MARK: - RhythmDisplayLogic
//
// Contract между `RhythmPresenter` и SwiftUI-view. View держит
// `@Observable RhythmDisplay` + тонкий Store-класс, реализующий этот
// протокол — Presenter пишет в него ViewModel'и, View реагирует.

@MainActor
protocol RhythmDisplayLogic: AnyObject {
    func displayLoadPattern(_ viewModel: RhythmModels.LoadPattern.ViewModel)
    func displayPlayPattern(_ viewModel: RhythmModels.PlayPattern.ViewModel)
    func displayStartRecord(_ viewModel: RhythmModels.StartRecord.ViewModel)
    func displayUpdateRMS(_ viewModel: RhythmModels.UpdateRMS.ViewModel)
    func displayEvaluateRhythm(_ viewModel: RhythmModels.EvaluateRhythm.ViewModel)
    func displayNextPattern(_ viewModel: RhythmModels.NextPattern.ViewModel)
    func displayComplete(_ viewModel: RhythmModels.Complete.ViewModel)
}
