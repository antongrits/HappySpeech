import Foundation

// MARK: - ParentVoiceNoteDisplayLogic

@MainActor
protocol ParentVoiceNoteDisplayLogic: AnyObject {
    func displayLoad(viewModel: ParentVoiceNoteModels.Load.ViewModel) async
    func displaySave(savedClip: ParentVoiceClipData) async
    func displayDelete(deletedId: String) async
    func displayToggle(isEnabled: Bool) async
    func displayError(message: String) async
}
