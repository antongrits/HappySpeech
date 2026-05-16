import XCTest
@testable import HappySpeech

// MARK: - VoiceCloningPresenterTests
//
// Block AA v21 — Smoke tests для VoiceCloningPresenter.
// Presenter не имеет протокольного DisplayLogic — он пишет напрямую в VoiceCloningViewModel.
// 3 теста: presentLoad (empty→state.empty), presentLoad (samples→state.ready), presentDelete.

@MainActor
final class VoiceCloningPresenterTests: XCTestCase {

    private var sut: VoiceCloningPresenter!
    private var viewModel: VoiceCloningViewModel!

    override func setUp() {
        super.setUp()
        viewModel = VoiceCloningViewModel()
        sut = VoiceCloningPresenter()
        sut.viewModel = viewModel
    }

    override func tearDown() {
        sut = nil
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_presentLoad_emptySamples_setsStateEmpty() {
        // Arrange
        let response = VoiceCloning.LoadResponse(
            samples: [],
            suggestedWord: "сом",
            targetSound: "С"
        )
        // Act
        sut.presentLoad(response)
        // Assert
        XCTAssertEqual(viewModel.state, .empty)
        XCTAssertTrue(viewModel.archiveSections.isEmpty)
    }

    func test_presentLoad_withSamples_setsStateReady() {
        // Arrange
        let sample = VoiceSampleData(
            id: "sample-1",
            childId: "child-1",
            word: "рыба",
            targetSound: "Р",
            audioFilePath: "VoiceArchive/child-1/sample_1.m4a",
            durationSeconds: 4.0,
            recordedAt: Date(),
            note: ""
        )
        let response = VoiceCloning.LoadResponse(
            samples: [sample],
            suggestedWord: "рак",
            targetSound: "Р"
        )
        // Act
        sut.presentLoad(response)
        // Assert
        XCTAssertEqual(viewModel.state, .ready)
        XCTAssertEqual(viewModel.totalSamplesCount, 1)
        XCTAssertEqual(viewModel.suggestedWord, "рак")
    }

    func test_presentRecordingState_updatesProgress() {
        // Arrange
        let response = VoiceCloning.RecordingStateResponse(
            isRecording: true,
            elapsedSeconds: 2.5,
            amplitude: 0.6
        )
        // Act
        sut.presentRecordingState(response)
        // Assert
        XCTAssertTrue(viewModel.isRecording)
        XCTAssertEqual(viewModel.recordingProgress, 0.5, accuracy: 0.01, "2.5/5.0 = 0.5")
    }

    func test_presentRecordingState_notRecording_progressZero() {
        sut.presentRecordingState(.init(isRecording: false, elapsedSeconds: 0, amplitude: 0))
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertEqual(viewModel.recordingProgress, 0.0, accuracy: 0.01)
    }

    func test_presentRecordingState_progressCappedAt1() {
        sut.presentRecordingState(.init(isRecording: true, elapsedSeconds: 10.0, amplitude: 0.9))
        XCTAssertEqual(viewModel.recordingProgress, 1.0, accuracy: 0.01)
    }

    func test_presentRecordingState_amplitudePropagated() {
        sut.presentRecordingState(.init(isRecording: true, elapsedSeconds: 1.0, amplitude: 0.75))
        XCTAssertEqual(viewModel.recordingAmplitude, 0.75, accuracy: 0.01)
    }

    func test_presentRecordingResult_success_toastNotNil() {
        sut.presentRecordingResult(.init(success: true, savedSampleId: "s-1", errorMessage: nil))
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertEqual(viewModel.lastSavedSampleId, "s-1")
        XCTAssertNotNil(viewModel.toastMessage)
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_presentRecordingResult_failure_errorNotNil() {
        sut.presentRecordingResult(.init(success: false, savedSampleId: nil, errorMessage: "Ошибка записи"))
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertEqual(viewModel.errorMessage, "Ошибка записи")
        XCTAssertNil(viewModel.toastMessage)
    }

    func test_presentRecordingResult_failure_nilErrorMessage_usesGeneric() {
        sut.presentRecordingResult(.init(success: false, savedSampleId: nil, errorMessage: nil))
        XCTAssertFalse(viewModel.errorMessage?.isEmpty ?? true)
    }

    func test_presentPlayback_playing_updatesState() {
        sut.presentPlayback(.init(isPlaying: true, currentSampleId: "s-1"))
        XCTAssertTrue(viewModel.isPlaying)
        XCTAssertEqual(viewModel.currentlyPlayingSampleId, "s-1")
    }

    func test_presentPlayback_stopped_clearsId() {
        sut.presentPlayback(.init(isPlaying: false, currentSampleId: nil))
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertNil(viewModel.currentlyPlayingSampleId)
    }

    func test_presentDelete_success_removesRow() {
        // Сначала загружаем samples
        let sample = VoiceSampleData(
            id: "del-1",
            childId: "child-1",
            word: "рыба",
            targetSound: "Р",
            audioFilePath: "path.m4a",
            durationSeconds: 3.0,
            recordedAt: Date(),
            note: ""
        )
        sut.presentLoad(.init(samples: [sample], suggestedWord: "рак", targetSound: "Р"))
        XCTAssertEqual(viewModel.totalSamplesCount, 1)

        sut.presentDelete(.init(success: true, deletedSampleId: "del-1"))
        XCTAssertEqual(viewModel.totalSamplesCount, 0)
        XCTAssertTrue(viewModel.archiveSections.isEmpty)
        XCTAssertNotNil(viewModel.toastMessage)
    }

    func test_presentDelete_failure_doesNotRemove() {
        let sample = VoiceSampleData(
            id: "del-2",
            childId: "child-1",
            word: "рыба",
            targetSound: "Р",
            audioFilePath: "path.m4a",
            durationSeconds: 3.0,
            recordedAt: Date(),
            note: ""
        )
        sut.presentLoad(.init(samples: [sample], suggestedWord: "рак", targetSound: "Р"))
        sut.presentDelete(.init(success: false, deletedSampleId: "del-2"))
        XCTAssertEqual(viewModel.totalSamplesCount, 1)
    }

    func test_presentError_setsStateError() {
        sut.presentError("Сеть недоступна")
        XCTAssertEqual(viewModel.errorMessage, "Сеть недоступна")
        if case .error(let msg) = viewModel.state {
            XCTAssertEqual(msg, "Сеть недоступна")
        } else {
            XCTFail("Ожидалось состояние .error, получено: \(viewModel.state)")
        }
    }
}
