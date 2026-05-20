import Foundation

// MARK: - ReadAloudStoryDisplayLogic
//
// v31 Волна D Ф.1 — контракт View ← Presenter.

@MainActor
protocol ReadAloudStoryDisplayLogic: AnyObject {
    func displayStart(viewModel: ReadAloudStoryModels.Start.ViewModel) async
    func displayNextSentence(viewModel: ReadAloudStoryModels.NextSentence.ViewModel) async
    func displayStartQuiz(viewModel: ReadAloudStoryModels.StartQuiz.ViewModel) async
    func displayAnswer(viewModel: ReadAloudStoryModels.Answer.ViewModel) async
}
