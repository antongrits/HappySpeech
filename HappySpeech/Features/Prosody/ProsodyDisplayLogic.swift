import Foundation

// MARK: - ProsodyDisplayLogic
//
// v29 Фаза 8, Функция 1 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol ProsodyDisplayLogic: AnyObject {
    func displayStart(viewModel: ProsodyModels.Start.ViewModel) async
    func displayAnswer(viewModel: ProsodyModels.Answer.ViewModel) async
}
