import Foundation

// MARK: - VoiceJournalDisplayLogic

/// Контракт Presenter → View (Holder).
@MainActor
protocol VoiceJournalDisplayLogic: AnyObject {
    func displayLoadEntries(viewModel: VoiceJournalModels.LoadEntries.ViewModel) async
    func displayRecordingStarted() async
    func displayRecordingFailed(message: String) async
    func displayRecordingSaved(viewModel: VoiceJournalModels.LoadEntries.ViewModel) async
}
