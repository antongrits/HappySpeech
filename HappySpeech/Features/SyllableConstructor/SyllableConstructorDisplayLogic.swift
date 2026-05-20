import Foundation

// MARK: - SyllableConstructorDisplayLogic

@MainActor
protocol SyllableConstructorDisplayLogic: AnyObject {
    func displayStart(viewModel: SyllableConstructorModels.Start.ViewModel) async
    func displaySubmit(viewModel: SyllableConstructorModels.SubmitGuess.ViewModel) async
}
