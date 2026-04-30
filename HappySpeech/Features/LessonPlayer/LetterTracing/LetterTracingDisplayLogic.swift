import Foundation

// MARK: - LetterTracingDisplayLogic

/// Контракт между Presenter и View.
@MainActor
protocol LetterTracingDisplayLogic: AnyObject {
    func displayLoadExercise(_ viewModel: LetterTracingModels.LoadExercise.ViewModel)
    func displaySubmitDrawing(_ viewModel: LetterTracingModels.SubmitDrawing.ViewModel)
    func displayResetCanvas(_ viewModel: LetterTracingModels.ResetCanvas.ViewModel)
    func displayCompleteSession(_ viewModel: LetterTracingModels.CompleteSession.ViewModel)
}

// MARK: - LetterTracingPresentationLogic

/// Контракт Interactor → Presenter.
@MainActor
protocol LetterTracingPresentationLogic: AnyObject {
    func presentLoadExercise(_ response: LetterTracingModels.LoadExercise.Response)
    func presentSubmitDrawing(_ response: LetterTracingModels.SubmitDrawing.Response)
    func presentResetCanvas(_ response: LetterTracingModels.ResetCanvas.Response)
    func presentCompleteSession(_ response: LetterTracingModels.CompleteSession.Response)
}

// MARK: - LetterTracingRoutingLogic

/// Навигационный контракт.
@MainActor
protocol LetterTracingRoutingLogic: AnyObject {
    func routeToCompleteWith(score: Float)
}

// MARK: - LetterTracingBusinessLogic

/// Контракт View → Interactor.
@MainActor
protocol LetterTracingBusinessLogic: AnyObject {
    func loadExercise(_ request: LetterTracingModels.LoadExercise.Request) async
    func submitDrawing(_ request: LetterTracingModels.SubmitDrawing.Request) async
    func resetCanvas(_ request: LetterTracingModels.ResetCanvas.Request)
}
