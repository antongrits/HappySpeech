import Foundation

// MARK: - FamilyAwardsCabinetDisplayLogic
//
// Block AE batch 2 v21 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol FamilyAwardsCabinetDisplayLogic: AnyObject {
    func displayLoad(viewModel: FamilyAwardsCabinetModels.Load.ViewModel) async
    func displaySelectAward(viewModel: FamilyAwardsCabinetModels.SelectAward.ViewModel) async
}
