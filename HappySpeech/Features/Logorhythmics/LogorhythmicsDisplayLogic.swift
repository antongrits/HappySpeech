import Foundation

// MARK: - LogorhythmicsDisplayLogic

/// Контракт Presenter → View (Holder).
@MainActor
protocol LogorhythmicsDisplayLogic: AnyObject {
    func displayLoadExercises(viewModel: LogorhythmicsModels.LoadExercises.ViewModel) async
    func displaySelectExercise(viewModel: LogorhythmicsModels.SelectExercise.ViewModel) async
    func displayBeatTick(viewModel: LogorhythmicsModels.BeatTick.ViewModel) async
    func displayFinishExercise(viewModel: LogorhythmicsModels.FinishExercise.ViewModel) async
}
