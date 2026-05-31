import Foundation

// MARK: - WhoseTailDisplayLogic
//
// F2-006 «Чей хвост / чей домик» — Clean Swift: контракт View ← Presenter.

@MainActor
protocol WhoseTailDisplayLogic: AnyObject {
    func displayStart(viewModel: WhoseTailModels.Start.ViewModel) async
    func displayAnswer(viewModel: WhoseTailModels.Answer.ViewModel) async
}
