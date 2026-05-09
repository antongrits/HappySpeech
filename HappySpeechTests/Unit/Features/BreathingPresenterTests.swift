@testable import HappySpeech
import XCTest

// MARK: - BreathingPresenterTests
//
// Block V v18 — покрытие BreathingPresenter (6 тестов).
// Тестируются presentLoadSession и presentSubmitAttempt через DisplaySpy.

@MainActor
final class BreathingPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: BreathingDisplayLogic {
        var loadSessionVM: BreathingModels.LoadSession.ViewModel?
        var submitAttemptVM: BreathingModels.SubmitAttempt.ViewModel?
        var updateSignalVM: BreathingModels.UpdateSignal.ViewModel?
        var finishVM: BreathingModels.Finish.ViewModel?

        func displayLoadSession(_ viewModel: BreathingModels.LoadSession.ViewModel) { loadSessionVM = viewModel }
        func displaySubmitAttempt(_ viewModel: BreathingModels.SubmitAttempt.ViewModel) { submitAttemptVM = viewModel }
        func displayUpdateSignal(_ viewModel: BreathingModels.UpdateSignal.ViewModel) { updateSignalVM = viewModel }
        func displayFinish(_ viewModel: BreathingModels.Finish.ViewModel) { finishVM = viewModel }
    }

    private func makeSUT() -> (BreathingPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = BreathingPresenter()
        presenter.viewModel = spy
        return (presenter, spy)
    }

    // MARK: - presentLoadSession

    func test_presentLoadSession_dandelion_setsTitleText() {
        let (sut, spy) = makeSUT()
        var response = BreathingModels.LoadSession.Response()
        response.scene = .dandelion
        sut.presentLoadSession(response)
        XCTAssertNotNil(spy.loadSessionVM)
        XCTAssertFalse(spy.loadSessionVM?.titleText.isEmpty ?? true)
    }

    func test_presentLoadSession_candle_setsTitleText() {
        let (sut, spy) = makeSUT()
        var response = BreathingModels.LoadSession.Response()
        response.scene = .candle
        sut.presentLoadSession(response)
        XCTAssertFalse(spy.loadSessionVM?.titleText.isEmpty ?? true)
    }

    func test_presentLoadSession_balloon_setsTitleText() {
        let (sut, spy) = makeSUT()
        var response = BreathingModels.LoadSession.Response()
        response.scene = .balloon
        sut.presentLoadSession(response)
        XCTAssertFalse(spy.loadSessionVM?.titleText.isEmpty ?? true)
    }

    func test_presentLoadSession_scenePreserved() {
        let (sut, spy) = makeSUT()
        var response = BreathingModels.LoadSession.Response()
        response.scene = .candle
        sut.presentLoadSession(response)
        XCTAssertEqual(spy.loadSessionVM?.scene, .candle)
    }

    // MARK: - presentSubmitAttempt

    func test_presentSubmitAttempt_correct_positiveFeedback() {
        let (sut, spy) = makeSUT()
        var response = BreathingModels.SubmitAttempt.Response()
        response.isCorrect = true
        sut.presentSubmitAttempt(response)
        XCTAssertTrue(spy.submitAttemptVM?.isCorrect ?? false)
        XCTAssertFalse(spy.submitAttemptVM?.feedbackText.isEmpty ?? true)
    }

    func test_presentSubmitAttempt_incorrect_negativeFeedback() {
        let (sut, spy) = makeSUT()
        var response = BreathingModels.SubmitAttempt.Response()
        response.isCorrect = false
        sut.presentSubmitAttempt(response)
        XCTAssertFalse(spy.submitAttemptVM?.isCorrect ?? true)
        XCTAssertFalse(spy.submitAttemptVM?.feedbackText.isEmpty ?? true)
    }
}
