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

    // MARK: - Batch 2.6a v25: diagnostic / replay / hint / sloMo / complete

    func test_presentEvaluateAttempt_diagnostic_none_noDiagnosticText() {
        let (sut, spy) = makeSUT()
        sut.presentEvaluateAttempt(makeEvaluateResponse(diagnostic: .none))
        XCTAssertNil(spy.evaluateAttemptVM?.diagnosticText)
    }

    func test_presentEvaluateAttempt_diagnostic_distortion_setsText() {
        let (sut, spy) = makeSUT()
        sut.presentEvaluateAttempt(makeEvaluateResponse(diagnostic: .distortion))
        XCTAssertNotNil(spy.evaluateAttemptVM?.diagnosticText)
        XCTAssertFalse(spy.evaluateAttemptVM?.diagnosticText?.isEmpty ?? true)
    }

    func test_presentEvaluateAttempt_diagnostic_substitution_setsText() {
        let (sut, spy) = makeSUT()
        sut.presentEvaluateAttempt(makeEvaluateResponse(diagnostic: .substitution))
        XCTAssertNotNil(spy.evaluateAttemptVM?.diagnosticText)
    }

    func test_presentEvaluateAttempt_diagnostic_omission_setsText() {
        let (sut, spy) = makeSUT()
        sut.presentEvaluateAttempt(makeEvaluateResponse(diagnostic: .omission))
        XCTAssertNotNil(spy.evaluateAttemptVM?.diagnosticText)
    }

    func test_presentEvaluateAttempt_diagnostic_addition_setsText() {
        let (sut, spy) = makeSUT()
        sut.presentEvaluateAttempt(makeEvaluateResponse(diagnostic: .addition))
        XCTAssertNotNil(spy.evaluateAttemptVM?.diagnosticText)
    }

    // MARK: - presentReplayModel

    func test_presentReplayModel_underLimit_countLabel() {
        let (sut, spy) = makeSUT()
        sut.presentReplayModel(RepeatAfterModelModels.ReplayModel.Response(
            word: makeWordItem(),
            replayCount: 1,
            replayLimitReached: false,
            audioFilename: "model.m4a"
        ))
        XCTAssertNotNil(spy.replayModelVM)
        XCTAssertEqual(spy.replayModelVM?.replayCount, 1)
        XCTAssertFalse(spy.replayModelVM?.replayLimitReached ?? true)
        XCTAssertFalse(spy.replayModelVM?.replayLabel.isEmpty ?? true)
    }

    func test_presentReplayModel_limitReached_limitLabel() {
        let (sut, spy) = makeSUT()
        sut.presentReplayModel(RepeatAfterModelModels.ReplayModel.Response(
            word: makeWordItem(),
            replayCount: 3,
            replayLimitReached: true,
            audioFilename: "model.m4a"
        ))
        XCTAssertTrue(spy.replayModelVM?.replayLimitReached ?? false)
        XCTAssertFalse(spy.replayModelVM?.replayLabel.isEmpty ?? true)
    }

    // MARK: - presentHint

    func test_presentHint_none_emptyLabel() {
        let (sut, spy) = makeSUT()
        sut.presentHint(makeHintResponse(level: .none))
        XCTAssertEqual(spy.hintVM?.hintLabel, "")
    }

    func test_presentHint_syllabification_setsLabel() {
        let (sut, spy) = makeSUT()
        sut.presentHint(makeHintResponse(level: .syllabification))
        XCTAssertFalse(spy.hintVM?.hintLabel.isEmpty ?? true)
        XCTAssertEqual(spy.hintVM?.hintLevel, .syllabification)
    }

    func test_presentHint_articulationDiagram_setsLabel() {
        let (sut, spy) = makeSUT()
        sut.presentHint(makeHintResponse(level: .articulationDiagram))
        XCTAssertFalse(spy.hintVM?.hintLabel.isEmpty ?? true)
    }

    func test_presentHint_sloMoReplay_setsLabel() {
        let (sut, spy) = makeSUT()
        sut.presentHint(makeHintResponse(level: .sloMoReplay))
        XCTAssertFalse(spy.hintVM?.hintLabel.isEmpty ?? true)
    }

    // MARK: - presentSloMo

    func test_presentSloMo_setsRateLabel() {
        let (sut, spy) = makeSUT()
        sut.presentSloMo(RepeatAfterModelModels.SloMo.Response(
            audioFilename: "model.m4a",
            playbackRate: 0.5,
            word: makeWordItem()
        ))
        XCTAssertNotNil(spy.sloMoVM)
        if let rate = spy.sloMoVM?.playbackRate {
            XCTAssertEqual(Double(rate), 0.5, accuracy: 0.001)
        } else {
            XCTFail("playbackRate должен быть заполнен")
        }
        XCTAssertFalse(spy.sloMoVM?.sloMoLabel.isEmpty ?? true)
    }

    // MARK: - presentCompleteSession (message buckets)

    func test_presentCompleteSession_excellent_above80() {
        let (sut, spy) = makeSUT()
        sut.presentCompleteSession(makeCompleteResponse(totalScore: 0.9))
        XCTAssertNotNil(spy.completeSessionVM)
        XCTAssertFalse(spy.completeSessionVM?.message.isEmpty ?? true)
        XCTAssertEqual(spy.completeSessionVM?.normalizedScore ?? -1, 0.9, accuracy: 0.001)
    }

    func test_presentCompleteSession_good_60to80() {
        let (sut, spy) = makeSUT()
        sut.presentCompleteSession(makeCompleteResponse(totalScore: 0.7))
        XCTAssertFalse(spy.completeSessionVM?.message.isEmpty ?? true)
    }

    func test_presentCompleteSession_keepGoing_40to60() {
        let (sut, spy) = makeSUT()
        sut.presentCompleteSession(makeCompleteResponse(totalScore: 0.5))
        XCTAssertFalse(spy.completeSessionVM?.message.isEmpty ?? true)
    }

    func test_presentCompleteSession_tryAgain_below40() {
        let (sut, spy) = makeSUT()
        sut.presentCompleteSession(makeCompleteResponse(totalScore: 0.2))
        XCTAssertFalse(spy.completeSessionVM?.message.isEmpty ?? true)
    }

    func test_presentCompleteSession_clampsNormalizedScore() {
        let (sut, spy) = makeSUT()
        sut.presentCompleteSession(makeCompleteResponse(totalScore: 1.5))
        XCTAssertEqual(spy.completeSessionVM?.normalizedScore ?? -1, 1.0, accuracy: 0.001)
    }

    // MARK: - Helpers

    private func makeEvaluateResponse(
        diagnostic: PronunciationDiagnostic
    ) -> RepeatAfterModelModels.EvaluateAttempt.Response {
        RepeatAfterModelModels.EvaluateAttempt.Response(
            score: 0.7,
            passed: true,
            feedback: "Хорошо",
            attemptsLeft: 2,
            canAdvance: true,
            diagnostic: diagnostic,
            encouragement: "Молодец",
            hintLevel: .syllabification,
            stars: 2
        )
    }

    private func makeHintResponse(
        level: RepeatHintLevel
    ) -> RepeatAfterModelModels.Hint.Response {
        RepeatAfterModelModels.Hint.Response(
            hintLevel: level,
            syllabification: "ры-ба",
            articulationAsset: "articulation_r",
            word: makeWordItem()
        )
    }

    private func makeCompleteResponse(
        totalScore: Float
    ) -> RepeatAfterModelModels.CompleteSession.Response {
        RepeatAfterModelModels.CompleteSession.Response(
            totalScore: totalScore,
            starsEarned: 2,
            totalAttempts: 8,
            wordsWithPerfectScore: 3,
            wordsCompleted: 5
        )
    }
}
