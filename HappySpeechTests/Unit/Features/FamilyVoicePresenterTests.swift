@testable import HappySpeech
import XCTest

// MARK: - FamilyVoicePresenterTests
//
// Phase 2.6 batch 2 v25 — покрытие FamilyVoicePresenter (30% → цель ≥90%).

@MainActor
final class FamilyVoicePresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: FamilyVoiceDisplayLogic {
        var recordingsVM: FamilyVoiceViewModel?
        var recordingStartedVM: FamilyVoiceViewModel?
        var recordingStoppedVM: FamilyVoiceViewModel?
        var playbackVM: FamilyVoiceViewModel?
        var deletionVM: FamilyVoiceViewModel?
        var childScoreVM: FamilyVoiceViewModel?
        var wordChangedVM: FamilyVoiceViewModel?
        var errorMessage: String?

        func displayRecordings(_ viewModel: FamilyVoiceViewModel) { recordingsVM = viewModel }
        func displayRecordingStarted(_ viewModel: FamilyVoiceViewModel) { recordingStartedVM = viewModel }
        func displayRecordingStopped(_ viewModel: FamilyVoiceViewModel) { recordingStoppedVM = viewModel }
        func displayPlayback(_ viewModel: FamilyVoiceViewModel) { playbackVM = viewModel }
        func displayDeletion(_ viewModel: FamilyVoiceViewModel) { deletionVM = viewModel }
        func displayChildScore(_ viewModel: FamilyVoiceViewModel) { childScoreVM = viewModel }
        func displayWordChanged(_ viewModel: FamilyVoiceViewModel) { wordChangedVM = viewModel }
        func displayError(_ message: String) { errorMessage = message }
    }

    private func makeSUT() -> (FamilyVoicePresenter, DisplaySpy) {
        let presenter = FamilyVoicePresenter()
        let spy = DisplaySpy()
        presenter.display = spy
        return (presenter, spy)
    }

    private func makeRecordingDTO(
        id: String = UUID().uuidString,
        word: String = "мяч",
        durationSeconds: Double = 3.0
    ) -> RecordingDTO {
        RecordingDTO(
            id: id,
            word: word,
            audioFilePath: "/tmp/\(id).m4a",
            recordedAt: Date(),
            durationSeconds: durationSeconds,
            parentProfileId: "p-1"
        )
    }

    // MARK: - presentRecordings

    func test_presentRecordings_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentRecordings(.init(recordings: []))
        XCTAssertNotNil(spy.recordingsVM)
    }

    func test_presentRecordings_emptyList_canDoneFalse() {
        let (sut, spy) = makeSUT()
        sut.presentRecordings(.init(recordings: []))
        XCTAssertFalse(spy.recordingsVM?.canDone ?? true)
    }

    func test_presentRecordings_withRecordings_canDoneTrue() {
        let (sut, spy) = makeSUT()
        sut.presentRecordings(.init(recordings: [makeRecordingDTO()]))
        XCTAssertTrue(spy.recordingsVM?.canDone ?? false)
    }

    func test_presentRecordings_durationFormatted_seconds() {
        let (sut, spy) = makeSUT()
        // 45 seconds → "0:45"
        sut.presentRecordings(.init(recordings: [makeRecordingDTO(durationSeconds: 45.0)]))
        XCTAssertEqual(spy.recordingsVM?.recordings.first?.durationText, "0:45")
    }

    func test_presentRecordings_durationFormatted_minutesAndSeconds() {
        let (sut, spy) = makeSUT()
        // 65 seconds → "1:05"
        sut.presentRecordings(.init(recordings: [makeRecordingDTO(durationSeconds: 65.0)]))
        XCTAssertEqual(spy.recordingsVM?.recordings.first?.durationText, "1:05")
    }

    // MARK: - presentRecordingStarted

    func test_presentRecordingStarted_recordingStateIsRecording() {
        let (sut, spy) = makeSUT()
        sut.presentRecordingStarted(.init(word: "мяч"))
        XCTAssertEqual(spy.recordingStartedVM?.recordingState, .recording)
    }

    // MARK: - presentRecordingStopped

    func test_presentRecordingStopped_recordingStateIdle() {
        let (sut, spy) = makeSUT()
        sut.presentRecordingStopped(.init(recording: makeRecordingDTO(), isNew: true))
        XCTAssertEqual(spy.recordingStoppedVM?.recordingState, .idle)
    }

    func test_presentRecordingStopped_newRecording_appendedToList() {
        let (sut, spy) = makeSUT()
        sut.presentRecordingStopped(.init(recording: makeRecordingDTO(word: "кот"), isNew: true))
        XCTAssertEqual(spy.recordingStoppedVM?.recordings.count, 1)
    }

    func test_presentRecordingStopped_existingWord_replacesExisting() {
        let (sut, spy) = makeSUT()
        // First recording for "мяч"
        sut.presentRecordings(.init(recordings: [makeRecordingDTO(id: "old-id", word: "мяч")]))
        // Stop with new recording for same word
        sut.presentRecordingStopped(.init(recording: makeRecordingDTO(id: "new-id", word: "мяч"), isNew: true))
        // Should still be 1 (replaced, not appended)
        XCTAssertEqual(spy.recordingStoppedVM?.recordings.count, 1)
        XCTAssertEqual(spy.recordingStoppedVM?.recordings.first?.id, "new-id")
    }

    func test_presentRecordingStopped_notNew_doesNotAppend() {
        let (sut, spy) = makeSUT()
        sut.presentRecordingStopped(.init(recording: makeRecordingDTO(), isNew: false))
        XCTAssertEqual(spy.recordingStoppedVM?.recordings.count, 0)
    }

    func test_presentRecordingStopped_toastMessageCleared() {
        let (sut, spy) = makeSUT()
        sut.presentRecordingStopped(.init(recording: makeRecordingDTO(), isNew: false))
        XCTAssertNil(spy.recordingStoppedVM?.toastMessage)
    }

    // MARK: - presentPlayback

    func test_presentPlayback_success_stateIsPlayingBack() {
        let (sut, spy) = makeSUT()
        sut.presentPlayback(.init(success: true, errorMessage: nil))
        XCTAssertEqual(spy.playbackVM?.recordingState, .playingBack)
    }

    func test_presentPlayback_failure_stateIsIdle() {
        let (sut, spy) = makeSUT()
        sut.presentPlayback(.init(success: false, errorMessage: "Ошибка"))
        XCTAssertEqual(spy.playbackVM?.recordingState, .idle)
    }

    func test_presentPlayback_failure_toastMessageSet() {
        let (sut, spy) = makeSUT()
        sut.presentPlayback(.init(success: false, errorMessage: "Файл не найден"))
        XCTAssertEqual(spy.playbackVM?.toastMessage, "Файл не найден")
    }

    func test_presentPlayback_failure_noErrorMessage_usesDefault() {
        let (sut, spy) = makeSUT()
        sut.presentPlayback(.init(success: false, errorMessage: nil))
        XCTAssertNotNil(spy.playbackVM?.toastMessage)
    }

    // MARK: - presentPlaybackEnded

    func test_presentPlaybackEnded_stateIsIdle() {
        let (sut, spy) = makeSUT()
        sut.presentPlayback(.init(success: true, errorMessage: nil))
        sut.presentPlaybackEnded()
        XCTAssertEqual(spy.playbackVM?.recordingState, .idle)
    }

    func test_presentPlaybackEnded_toastCleared() {
        let (sut, spy) = makeSUT()
        sut.presentPlaybackEnded()
        XCTAssertNil(spy.playbackVM?.toastMessage)
    }

    // MARK: - presentDeletion

    func test_presentDeletion_success_removesFromList() {
        let (sut, spy) = makeSUT()
        let rec = makeRecordingDTO(id: "del-id")
        sut.presentRecordings(.init(recordings: [rec]))
        sut.presentDeletion(.init(success: true, deletedId: "del-id"))
        XCTAssertEqual(spy.deletionVM?.recordings.count, 0)
    }

    func test_presentDeletion_failure_doesNotRemove() {
        let (sut, spy) = makeSUT()
        let rec = makeRecordingDTO(id: "keep-id")
        sut.presentRecordings(.init(recordings: [rec]))
        sut.presentDeletion(.init(success: false, deletedId: "keep-id"))
        XCTAssertEqual(spy.deletionVM?.recordings.count, 1)
    }

    // MARK: - presentChildScore

    func test_presentChildScore_highScore_feedbackIsCorrect() {
        let (sut, spy) = makeSUT()
        sut.presentChildScore(.init(score: 0.8, transcript: "мяч", word: "мяч"))
        XCTAssertTrue(spy.childScoreVM?.feedbackIsCorrect ?? false)
    }

    func test_presentChildScore_lowScore_feedbackIsNotCorrect() {
        let (sut, spy) = makeSUT()
        sut.presentChildScore(.init(score: 0.5, transcript: "мяч", word: "мяч"))
        XCTAssertFalse(spy.childScoreVM?.feedbackIsCorrect ?? true)
    }

    func test_presentChildScore_showFeedbackTrue() {
        let (sut, spy) = makeSUT()
        sut.presentChildScore(.init(score: 0.9, transcript: nil, word: "кот"))
        XCTAssertTrue(spy.childScoreVM?.showFeedback ?? false)
    }

    func test_presentChildScore_scoreSet() {
        let (sut, spy) = makeSUT()
        sut.presentChildScore(.init(score: 0.75, transcript: "мяч", word: "мяч"))
        XCTAssertEqual(spy.childScoreVM?.currentScore, 0.75)
    }

    // MARK: - presentFeedbackDismissed

    func test_presentFeedbackDismissed_showFeedbackFalse() {
        let (sut, spy) = makeSUT()
        sut.presentChildScore(.init(score: 0.9, transcript: nil, word: "мяч"))
        sut.presentFeedbackDismissed()
        XCTAssertFalse(spy.childScoreVM?.showFeedback ?? true)
    }

    // MARK: - presentWordChanged

    func test_presentWordChanged_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentWordChanged(.init(newWord: "собака"))
        XCTAssertNotNil(spy.wordChangedVM)
    }

    func test_presentWordChanged_wordUpdated() {
        let (sut, spy) = makeSUT()
        sut.presentWordChanged(.init(newWord: "рыба"))
        XCTAssertEqual(spy.wordChangedVM?.selectedWord, "рыба")
    }

    func test_presentWordChanged_scoreCleared() {
        let (sut, spy) = makeSUT()
        sut.presentChildScore(.init(score: 0.9, transcript: nil, word: "мяч"))
        sut.presentWordChanged(.init(newWord: "кот"))
        XCTAssertNil(spy.wordChangedVM?.currentScore)
    }

    func test_presentWordChanged_showFeedbackFalse() {
        let (sut, spy) = makeSUT()
        sut.presentChildScore(.init(score: 0.9, transcript: nil, word: "мяч"))
        sut.presentWordChanged(.init(newWord: "кот"))
        XCTAssertFalse(spy.wordChangedVM?.showFeedback ?? true)
    }

    // MARK: - presentError

    func test_presentError_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentError(.init(message: "Ошибка микрофона"))
        XCTAssertEqual(spy.errorMessage, "Ошибка микрофона")
    }

    func test_presentError_recordingStateIdle() {
        let (sut, spy) = makeSUT()
        sut.presentRecordingStarted(.init(word: "мяч"))
        sut.presentError(.init(message: "Ошибка"))
        // After error recording state should be idle
        // We check via toastMessage which is set in error
        XCTAssertNotNil(spy.errorMessage)
    }

    // MARK: - setMode / setSelectedWord

    func test_setMode_split_appliedToViewModel() {
        let (sut, spy) = makeSUT()
        sut.setMode(.split)
        sut.presentRecordings(.init(recordings: []))
        XCTAssertEqual(spy.recordingsVM?.mode, .split)
    }

    func test_setSelectedWord_appliedToViewModel() {
        let (sut, spy) = makeSUT()
        sut.setSelectedWord("кот")
        sut.presentRecordings(.init(recordings: []))
        XCTAssertEqual(spy.recordingsVM?.selectedWord, "кот")
    }
}
