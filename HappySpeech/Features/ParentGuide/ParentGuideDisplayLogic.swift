import Foundation

// MARK: - ParentGuideDisplayLogic
//
// v29 Фаза 8, Функция 3 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol ParentGuideDisplayLogic: AnyObject {
    func displayLoad(viewModel: ParentGuideModels.Load.ViewModel) async
    func displayMarkRead(viewModel: ParentGuideModels.MarkRead.ViewModel) async
    func displayToggleFavorite(viewModel: ParentGuideModels.ToggleFavorite.ViewModel) async
}
