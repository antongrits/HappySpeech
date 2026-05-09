import Foundation

// MARK: - WeeklyChallengeDisplayLogic
//
// Block R.3 v18 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol WeeklyChallengeDisplayLogic: AnyObject {
    func displayLoad(viewModel: WeeklyChallengeModels.Load.ViewModel) async
    func displayMarkDay(viewModel: WeeklyChallengeModels.MarkDay.ViewModel) async
    func displaySwitchKind(viewModel: WeeklyChallengeModels.SwitchKind.ViewModel) async
}
