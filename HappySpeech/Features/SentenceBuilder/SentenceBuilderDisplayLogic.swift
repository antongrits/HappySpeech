import Foundation

// MARK: - SentenceBuilderDisplayLogic
//
// F2-004 «Конструктор предложения» — Clean Swift: контракт View ← Presenter.

@MainActor
protocol SentenceBuilderDisplayLogic: AnyObject {
    func displayStart(viewModel: SentenceBuilderModels.Start.ViewModel) async
    func displayAnswer(viewModel: SentenceBuilderModels.Answer.ViewModel) async
}
