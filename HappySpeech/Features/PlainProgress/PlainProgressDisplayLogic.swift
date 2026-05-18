import Foundation

// MARK: - PlainProgressDisplayLogic
//
// v29 Фаза 8, Функция 9 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol PlainProgressDisplayLogic: AnyObject {
    func displayLoad(viewModel: PlainProgressModels.Load.ViewModel) async
    func displayLoadFailure(message: String) async
    func displayShare(viewModel: PlainProgressModels.Share.ViewModel) async
}
