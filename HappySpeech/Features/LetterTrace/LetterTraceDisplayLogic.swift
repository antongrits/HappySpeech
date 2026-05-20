import Foundation

// MARK: - LetterTraceDisplayLogic

@MainActor
protocol LetterTraceDisplayLogic: AnyObject {
    func displayLoad(viewModel: LetterTraceModels.Load.ViewModel) async
    func displayAdvance(viewModel: LetterTraceModels.Advance.ViewModel) async
    func displayScore(viewModel: LetterTraceModels.Score.ViewModel) async
}

// MARK: - LetterTracePresentationLogic

@MainActor
protocol LetterTracePresentationLogic: AnyObject {
    func presentLoad(response: LetterTraceModels.Load.Response) async
    func presentAdvance(response: LetterTraceModels.Advance.Response) async
    func presentScore(response: LetterTraceModels.Score.Response) async
}
