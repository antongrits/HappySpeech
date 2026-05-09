import Foundation

// MARK: - LogopedistChatDisplayLogic
//
// Block R.2 v18 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol LogopedistChatDisplayLogic: AnyObject {
    func displayLoad(viewModel: LogopedistChatModels.Load.ViewModel) async
    func displaySend(viewModel: LogopedistChatModels.Send.ViewModel) async
    func displayAttachAudio(viewModel: LogopedistChatModels.AttachAudio.ViewModel) async
}
