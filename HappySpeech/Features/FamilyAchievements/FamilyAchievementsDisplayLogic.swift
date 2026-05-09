import Foundation

// MARK: - FamilyAchievementsDisplayLogic
//
// Block R.4 v18 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol FamilyAchievementsDisplayLogic: AnyObject {
    func displayLoad(viewModel: FamilyAchievementsModels.Load.ViewModel) async
    func displayRecompute(viewModel: FamilyAchievementsModels.Recompute.ViewModel) async
}
