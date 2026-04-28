import Foundation
import OSLog

// MARK: - FamilyVoicePresenter

@MainActor
final class FamilyVoicePresenter {

    weak var display: (any FamilyVoiceDisplayLogic)?

    private let logger = Logger(subsystem: "com.happyspeech", category: "FamilyVoicePresenter")

    // MARK: - State cache (presenter owns the last-known display state)

    private var currentMode: FamilyVoiceMode = .recorder
    private var currentRecordingState: RecordingState = .idle
    private var currentWord: String = FamilyVoiceModels.targetWordsRaw.first ?? "мяч"
    private var recordings: [RecordingItemViewModel] = []
    private var currentScore: Float?
    private var feedback: String?
    private var waveformLevels: [Float] = []
    private var liveTranscript: String?
    private var showFeedback: Bool = false
    private var feedbackIsCorrect: Bool = false
    private var toastMessage: String?

    // MARK: - Presentation

    func presentRecordings(_ response: FamilyVoiceModels.FetchRecordingsResponse) {
        recordings = response.recordings.map { makeItem(from: $0) }
        display?.displayRecordings(makeViewModel())
    }

    func presentRecordingStarted(_ response: FamilyVoiceModels.RecordingStartedResponse) {
        currentRecordingState = .recording
        logger.debug("Recording started: \(response.word)")
        display?.displayRecordingStarted(makeViewModel())
    }

    func presentRecordingStopped(_ response: FamilyVoiceModels.RecordingStoppedResponse) {
        currentRecordingState = .idle
        let item = makeItem(from: response.recording)
        if response.isNew {
            // Replace existing for same word or append
            if let idx = recordings.firstIndex(where: { $0.word == response.recording.word }) {
                recordings[idx] = item
            } else {
                recordings.append(item)
            }
        }
        toastMessage = nil
        display?.displayRecordingStopped(makeViewModel())
    }

    func presentPlayback(_ response: FamilyVoiceModels.PlaybackResponse) {
        if response.success {
            currentRecordingState = .playingBack
        } else {
            currentRecordingState = .idle
            toastMessage = response.errorMessage ?? String(localized: "parent_child.error.playback_failed")
        }
        display?.displayPlayback(makeViewModel())
    }

    func presentPlaybackEnded() {
        currentRecordingState = .idle
        toastMessage = nil
        display?.displayPlayback(makeViewModel())
    }

    func presentDeletion(_ response: FamilyVoiceModels.DeleteResponse) {
        if response.success {
            recordings.removeAll { $0.id == response.deletedId }
        }
        display?.displayDeletion(makeViewModel())
    }

    func presentChildScore(_ response: FamilyVoiceModels.ChildScoringResponse) {
        currentScore = response.score
        liveTranscript = response.transcript
        feedbackIsCorrect = response.score >= 0.75
        feedback = feedbackIsCorrect
            ? String(localized: "parent_child.split.feedback.great")
            : String(localized: "parent_child.split.feedback.try")
        showFeedback = true
        display?.displayChildScore(makeViewModel())
    }

    func presentFeedbackDismissed() {
        showFeedback = false
        display?.displayChildScore(makeViewModel())
    }

    func presentWordChanged(_ response: FamilyVoiceModels.WordChangedResponse) {
        currentWord = response.newWord
        currentScore = nil
        liveTranscript = nil
        showFeedback = false
        feedback = nil
        display?.displayWordChanged(makeViewModel())
    }

    func presentWaveformUpdate(levels: [Float]) {
        waveformLevels = levels
        // Lightweight — no full display refresh needed; caller updates directly
    }

    func presentError(_ response: FamilyVoiceModels.ErrorResponse) {
        currentRecordingState = .idle
        toastMessage = response.message
        display?.displayError(response.message)
    }

    func setMode(_ mode: FamilyVoiceMode) {
        currentMode = mode
    }

    func setSelectedWord(_ word: String) {
        currentWord = word
    }

    // MARK: - ViewModel factory

    private func makeViewModel() -> FamilyVoiceViewModel {
        FamilyVoiceViewModel(
            mode: currentMode,
            recordingState: currentRecordingState,
            selectedWord: currentWord,
            recordings: recordings,
            currentScore: currentScore,
            feedback: feedback,
            canDone: !recordings.isEmpty,
            waveformLevels: waveformLevels,
            liveTranscript: liveTranscript,
            showFeedback: showFeedback,
            feedbackIsCorrect: feedbackIsCorrect,
            toastMessage: toastMessage
        )
    }

    // MARK: - Helpers

    private func makeItem(from dto: RecordingDTO) -> RecordingItemViewModel {
        let duration = formatDuration(dto.durationSeconds)
        return RecordingItemViewModel(
            id: dto.id,
            word: dto.word,
            durationText: duration,
            recordedAt: dto.recordedAt,
            audioFilePath: dto.audioFilePath
        )
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        return String(format: "0:%02d", secs)
    }
}
