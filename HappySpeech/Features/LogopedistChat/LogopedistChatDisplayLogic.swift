import Foundation

// MARK: - LogopedistChatDisplayLogic
//
// Block R.2 v18 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol LogopedistChatDisplayLogic: AnyObject {
    func displayLoad(viewModel: LogopedistChatModels.Load.ViewModel) async
    func displaySend(viewModel: LogopedistChatModels.Send.ViewModel) async
    func displayAttachAudio(viewModel: LogopedistChatModels.AttachAudio.ViewModel) async
    func displayConnect(viewModel: LogopedistChatModels.Connect.ViewModel) async
    func displayRecording(viewModel: LogopedistChatModels.Recording.ViewModel) async
    func displayPlayback(viewModel: LogopedistChatModels.Playback.ViewModel) async
}

// Default no-op so existing display doubles (test spies) keep conforming
// without implementing the new connect / recording / playback surfaces.
extension LogopedistChatDisplayLogic {
    func displayConnect(viewModel: LogopedistChatModels.Connect.ViewModel) async {}
    func displayRecording(viewModel: LogopedistChatModels.Recording.ViewModel) async {}
    func displayPlayback(viewModel: LogopedistChatModels.Playback.ViewModel) async {}
}
