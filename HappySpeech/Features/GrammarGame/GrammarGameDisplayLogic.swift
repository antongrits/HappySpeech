import Foundation

// MARK: - GrammarGameDisplayLogic

/// Протокол View-слоя, получающего ViewModels от Presenter.
@MainActor
protocol GrammarGameDisplayLogic: AnyObject {
    func displayLoadGame(_ viewModel: GrammarGameModels.LoadGame.ViewModel)
    func displayRound(_ viewModel: GrammarGameModels.PresentRound.ViewModel)
    func displayEvaluateAnswer(_ viewModel: GrammarGameModels.EvaluateAnswer.ViewModel)
    func displayDragDrop(_ viewModel: GrammarGameModels.DragDrop.ViewModel)
    func displaySessionComplete(_ viewModel: GrammarGameModels.SessionComplete.ViewModel)
    func displayExitConfirmation(_ viewModel: GrammarGameModels.ExitConfirmation.ViewModel)
    func displayError(_ message: String)
}
