import Foundation

// MARK: - CoPlayDisplayLogic
//
// v29 Фаза 8, Функция 8 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol CoPlayDisplayLogic: AnyObject {
    func displayStart(viewModel: CoPlayModels.Start.ViewModel) async
    func displayNextTurn(viewModel: CoPlayModels.NextTurn.ViewModel) async
}
