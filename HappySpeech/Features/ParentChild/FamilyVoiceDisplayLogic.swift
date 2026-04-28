import Foundation

// MARK: - FamilyVoiceDisplayLogic

/// Protocol that FamilyVoiceView conforms to, allowing Presenter to push display updates.
@MainActor
protocol FamilyVoiceDisplayLogic: AnyObject {
    func displayRecordings(_ viewModel: FamilyVoiceViewModel)
    func displayRecordingStarted(_ viewModel: FamilyVoiceViewModel)
    func displayRecordingStopped(_ viewModel: FamilyVoiceViewModel)
    func displayPlayback(_ viewModel: FamilyVoiceViewModel)
    func displayDeletion(_ viewModel: FamilyVoiceViewModel)
    func displayChildScore(_ viewModel: FamilyVoiceViewModel)
    func displayWordChanged(_ viewModel: FamilyVoiceViewModel)
    func displayError(_ message: String)
}
