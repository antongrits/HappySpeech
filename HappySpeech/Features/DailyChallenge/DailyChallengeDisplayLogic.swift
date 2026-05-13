import Foundation

// MARK: - DailyChallengeDisplayLogic
//
// Block AE batch 2 v21 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol DailyChallengeDisplayLogic: AnyObject {
    func displayLoad(viewModel: DailyChallengeModels.Load.ViewModel) async
    func displayStartSession(viewModel: DailyChallengeModels.StartSession.ViewModel) async
    func displayShareCompletion(viewModel: DailyChallengeModels.ShareCompletion.ViewModel) async
}
