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
}
