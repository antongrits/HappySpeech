import Foundation

// MARK: - CulturalContentDisplayLogic
//
// Block R.5 v18 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol CulturalContentDisplayLogic: AnyObject {
    func displayLoad(viewModel: CulturalContentModels.Load.ViewModel) async
    func displayOpen(viewModel: CulturalContentModels.Open.ViewModel) async
    func displayToggleBookmark(viewModel: CulturalContentModels.ToggleBookmark.ViewModel) async
}
