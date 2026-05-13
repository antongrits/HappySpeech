import Foundation

// MARK: - HelpCenterDisplayLogic
//
// Block AE v21 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol HelpCenterDisplayLogic: AnyObject {
    func displayLoad(viewModel: HelpCenterModels.Load.ViewModel) async
    func displayToggleFAQ(viewModel: HelpCenterModels.ToggleFAQ.ViewModel) async
    func displaySelectVideo(viewModel: HelpCenterModels.SelectVideo.ViewModel) async
    func displayContactSupport(viewModel: HelpCenterModels.ContactSupport.ViewModel) async
}
