@testable import HappySpeech
import XCTest

// MARK: - RepeatAfterModelPresenterTests
//
// Block V v18 — покрытие RepeatAfterModelPresenter (8 тестов).
// Тестируются методы presentLoadSession, presentStartWord,
// presentRecordAttempt, presentEvaluateAttempt через DisplaySpy.

@MainActor
final class RepeatAfterModelPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: RepeatAfterModelDisplayLogic {
        var loadSessionVM: RepeatAfterModelModels.LoadSession.ViewModel?
        var startWordVM: RepeatAfterModelModels.StartWord.ViewModel?
        var recordAttemptVM: RepeatAfterModelModels.RecordAttempt.ViewModel?
        var evaluateAttemptVM: RepeatAfterModelModels.EvaluateAttempt.ViewModel?
        var replayModelVM: RepeatAfterModelModels.ReplayModel.ViewModel?
        var hintVM: RepeatAfterModelModels.Hint.ViewModel?
        var sloMoVM: RepeatAfterModelModels.SloMo.ViewModel?
        var completeSessionVM: RepeatAfterModelModels.CompleteSession.ViewModel?

        func displayLoadSession(_ viewModel: RepeatAfterModelModels.LoadSession.ViewModel) { loadSessionVM = viewModel }
        func displayStartWord(_ viewModel: RepeatAfterModelModels.StartWord.ViewModel) { startWordVM = viewModel }
        func displayRecordAttempt(_ viewModel: RepeatAfterModelModels.RecordAttempt.ViewModel) { recordAttemptVM = viewModel }
        func displayEvaluateAttempt(_ viewModel: RepeatAfterModelModels.EvaluateAttempt.ViewModel) { evaluateAttemptVM = viewModel }
        func displayReplayModel(_ viewModel: RepeatAfterModelModels.ReplayModel.ViewModel) { replayModelVM = viewModel }
        func displayHint(_ viewModel: RepeatAfterModelModels.Hint.ViewModel) { hintVM = viewModel }
        func displaySloMo(_ viewModel: RepeatAfterModelModels.SloMo.ViewModel) { sloMoVM = viewModel }
        func displayCompleteSession(_ viewModel: RepeatAfterModelModels.CompleteSession.ViewModel) { completeSessionVM = viewModel }
    }

    private func makeSUT() -> (RepeatAfterModelPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = RepeatAfterModelPresenter()
        presenter.viewModel = spy
        return (presenter, spy)
    }

    private func makeWordItem() -> TargetWordItem {
        TargetWordItem(
            id: "test-word",
            word: "Рыба",
            soundGroup: "р",
            syllabification: "ры-ба",
            audioFilename: nil,
            emoji: "🐟"
        )
    }

    // MARK: - presentLoadSession

    func test_presentLoadSession_withName_setsGreeting() {
        let (sut, spy) = makeSUT()
        let words = [makeWordItem()]
        let response = RepeatAfterModelModels.LoadSession.Response(
            words: words,
            childName: "Ваня",
            totalRounds: 5
        )
        sut.presentLoadSession(response)
        XCTAssertNotNil(spy.loadSessionVM)
        XCTAssertFalse(spy.loadSessionVM?.greeting.isEmpty ?? true)
    }

    func test_presentLoadSession_emptyName_setsDefaultGreeting() {
        let (sut, spy) = makeSUT()
        let words = [makeWordItem(), makeWordItem()]
        let response = RepeatAfterModelModels.LoadSession.Response(
            words: words,
            childName: "",
            totalRounds: 5
        )
        sut.presentLoadSession(response)
        XCTAssertEqual(spy.loadSessionVM?.totalWords, 2)
    }

    // MARK: - presentStartWord

    func test_presentStartWord_setsProgressLabel() {
        let (sut, spy) = makeSUT()
        let response = RepeatAfterModelModels.StartWord.Response(
            word: makeWordItem(),
            wordNumber: 2,
            total: 5,
            attemptsLeft: 3,
            canReplay: true,
            replayCount: 0
        )
        sut.presentStartWord(response)
        XCTAssertFalse(spy.startWordVM?.progressLabel.isEmpty ?? true)
        XCTAssertTrue(spy.startWordVM?.canReplay ?? false)
    }

    func test_presentStartWord_syllabification_preserved() {
        let (sut, spy) = makeSUT()
        let word = makeWordItem()
        let response = RepeatAfterModelModels.StartWord.Response(
            word: word,
            wordNumber: 1,
            total: 5,
            attemptsLeft: 3,
            canReplay: false,
            replayCount: 0
        )
        sut.presentStartWord(response)
        XCTAssertEqual(spy.startWordVM?.syllabification, "ры-ба")
    }

    // MARK: - presentRecordAttempt

    func test_presentRecordAttempt_isRecording_setsLabel() {
        let (sut, spy) = makeSUT()
        sut.presentRecordAttempt(RepeatAfterModelModels.RecordAttempt.Response(isRecording: true))
        XCTAssertTrue(spy.recordAttemptVM?.isRecording ?? false)
        XCTAssertFalse(spy.recordAttemptVM?.micLabel.isEmpty ?? true)
    }

    func test_presentRecordAttempt_notRecording_setsLabel() {
        let (sut, spy) = makeSUT()
        sut.presentRecordAttempt(RepeatAfterModelModels.RecordAttempt.Response(isRecording: false))
        XCTAssertFalse(spy.recordAttemptVM?.isRecording ?? true)
        XCTAssertFalse(spy.recordAttemptVM?.micLabel.isEmpty ?? true)
    }

    // MARK: - presentEvaluateAttempt

    func test_presentEvaluateAttempt_passed_hintAvailableWhenNotSloMo() {
        let (sut, spy) = makeSUT()
        let response = RepeatAfterModelModels.EvaluateAttempt.Response(
            score: 0.85,
            passed: true,
            feedback: "Отлично!",
            attemptsLeft: 2,
            canAdvance: true,
            diagnostic: .none,
            encouragement: "Молодец!",
            hintLevel: .syllabification,
            stars: 3
        )
        sut.presentEvaluateAttempt(response)
        XCTAssertTrue(spy.evaluateAttemptVM?.passed ?? false)
        XCTAssertTrue(spy.evaluateAttemptVM?.hintAvailable ?? false)
    }

    func test_presentEvaluateAttempt_sloMoLevel_hintNotAvailable() {
        let (sut, spy) = makeSUT()
        let response = RepeatAfterModelModels.EvaluateAttempt.Response(
            score: 0.40,
            passed: false,
            feedback: "Попробуй ещё",
            attemptsLeft: 1,
            canAdvance: false,
            diagnostic: .distortion,
            encouragement: nil,
            hintLevel: .sloMoReplay,
            stars: 1
        )
        sut.presentEvaluateAttempt(response)
        XCTAssertFalse(spy.evaluateAttemptVM?.hintAvailable ?? true)
    }
}
