@testable import HappySpeech
import XCTest

// MARK: - RhythmPresenterTests
//
// Phase 2.6.1 v25 — покрытие RhythmPresenter (14 тестов).
// Тестируются все 7 методов: presentLoadPattern, presentPlayPattern,
// presentStartRecord, presentUpdateRMS, presentEvaluateRhythm,
// presentNextPattern, presentComplete.

@MainActor
final class RhythmPresenterTests: XCTestCase {

    // MARK: - DisplaySpy

    @MainActor
    private final class DisplaySpy: RhythmDisplayLogic {
        var loadPatternVM: RhythmModels.LoadPattern.ViewModel?
        var playPatternVM: RhythmModels.PlayPattern.ViewModel?
        var startRecordCalled = false
        var updateRMSVM: RhythmModels.UpdateRMS.ViewModel?
        var evaluateRhythmVM: RhythmModels.EvaluateRhythm.ViewModel?
        var nextPatternCalled = false
        var completeVM: RhythmModels.Complete.ViewModel?

        func displayLoadPattern(_ viewModel: RhythmModels.LoadPattern.ViewModel) { loadPatternVM = viewModel }
        func displayPlayPattern(_ viewModel: RhythmModels.PlayPattern.ViewModel) { playPatternVM = viewModel }
        func displayStartRecord(_ viewModel: RhythmModels.StartRecord.ViewModel) { startRecordCalled = true }
        func displayUpdateRMS(_ viewModel: RhythmModels.UpdateRMS.ViewModel) { updateRMSVM = viewModel }
        func displayEvaluateRhythm(_ viewModel: RhythmModels.EvaluateRhythm.ViewModel) { evaluateRhythmVM = viewModel }
        func displayNextPattern(_ viewModel: RhythmModels.NextPattern.ViewModel) { nextPatternCalled = true }
        func displayComplete(_ viewModel: RhythmModels.Complete.ViewModel) { completeVM = viewModel }
    }

    private func makeSUT() -> (RhythmPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = RhythmPresenter()
        presenter.viewModel = spy
        return (presenter, spy)
    }

    private func makePattern(beats: [BeatStrength] = [.strong, .weak, .weak]) -> RhythmPattern {
        RhythmPattern(
            id: UUID(),
            beats: beats,
            syllableWord: "РА-ке-та",
            targetWord: "ракета",
            soundGroup: "sonants",
            emoji: "rocket",
            displayPattern: "ТА • та • та"
        )
    }

    // MARK: - presentLoadPattern

    func test_presentLoadPattern_beatsCount_matchesPattern() {
        let (sut, spy) = makeSUT()
        let pattern = makePattern(beats: [.strong, .weak, .weak])
        let response = RhythmModels.LoadPattern.Response(
            pattern: pattern,
            patternIndex: 0,
            totalPatterns: 5
        )
        sut.presentLoadPattern(response)
        XCTAssertNotNil(spy.loadPatternVM)
        XCTAssertEqual(spy.loadPatternVM?.beats.count, 3)
    }

    func test_presentLoadPattern_progressFraction_midpoint() {
        let (sut, spy) = makeSUT()
        let response = RhythmModels.LoadPattern.Response(
            pattern: makePattern(),
            patternIndex: 2,
            totalPatterns: 4
        )
        sut.presentLoadPattern(response)
        XCTAssertEqual(spy.loadPatternVM?.progressFraction ?? -1, 0.5, accuracy: 0.001)
    }

    func test_presentLoadPattern_passesWordsThrough() {
        let (sut, spy) = makeSUT()
        let response = RhythmModels.LoadPattern.Response(
            pattern: makePattern(),
            patternIndex: 0,
            totalPatterns: 5
        )
        sut.presentLoadPattern(response)
        XCTAssertEqual(spy.loadPatternVM?.syllableWord, "РА-ке-та")
        XCTAssertEqual(spy.loadPatternVM?.targetWord, "ракета")
    }

    // MARK: - presentPlayPattern

    func test_presentPlayPattern_passesActiveBeatIndex() {
        let (sut, spy) = makeSUT()
        sut.presentPlayPattern(RhythmModels.PlayPattern.Response(activeBeatIndex: 1))
        XCTAssertEqual(spy.playPatternVM?.activeBeatIndex, 1)
    }

    // MARK: - presentStartRecord

    func test_presentStartRecord_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentStartRecord(RhythmModels.StartRecord.Response())
        XCTAssertTrue(spy.startRecordCalled)
    }

    // MARK: - presentUpdateRMS

    func test_presentUpdateRMS_clampsBelowZero() {
        let (sut, spy) = makeSUT()
        sut.presentUpdateRMS(RhythmModels.UpdateRMS.Response(rmsLevel: -0.5, detectedBeats: 0))
        XCTAssertGreaterThanOrEqual(spy.updateRMSVM?.rmsLevel ?? -1, 0)
    }

    func test_presentUpdateRMS_clampsAboveOne() {
        let (sut, spy) = makeSUT()
        sut.presentUpdateRMS(RhythmModels.UpdateRMS.Response(rmsLevel: 1.5, detectedBeats: 2))
        XCTAssertLessThanOrEqual(spy.updateRMSVM?.rmsLevel ?? 2, 1)
        XCTAssertEqual(spy.updateRMSVM?.detectedBeats, 2)
    }

    // MARK: - presentEvaluateRhythm

    func test_presentEvaluateRhythm_correct_positiveFeedback() {
        let (sut, spy) = makeSUT()
        let response = RhythmModels.EvaluateRhythm.Response(
            score: 0.95,
            correct: true,
            detectedBeats: 3,
            expectedBeats: 3,
            beatsWasHit: [true, true, true]
        )
        sut.presentEvaluateRhythm(response)
        XCTAssertTrue(spy.evaluateRhythmVM?.feedbackCorrect ?? false)
        XCTAssertFalse(spy.evaluateRhythmVM?.feedbackText.isEmpty ?? true)
        XCTAssertEqual(spy.evaluateRhythmVM?.starsPreview, 3)
    }

    func test_presentEvaluateRhythm_tooManyBeats_specificFeedback() {
        let (sut, spy) = makeSUT()
        let response = RhythmModels.EvaluateRhythm.Response(
            score: 0.3,
            correct: false,
            detectedBeats: 4,
            expectedBeats: 3,
            beatsWasHit: [true, true, true, true]
        )
        sut.presentEvaluateRhythm(response)
        XCTAssertFalse(spy.evaluateRhythmVM?.feedbackCorrect ?? true)
        // «Слишком много слогов» — diff > 0
        XCTAssertFalse(spy.evaluateRhythmVM?.feedbackText.isEmpty ?? true)
    }

    func test_presentEvaluateRhythm_tooFewBeats_specificFeedback() {
        let (sut, spy) = makeSUT()
        let response = RhythmModels.EvaluateRhythm.Response(
            score: 0.2,
            correct: false,
            detectedBeats: 1,
            expectedBeats: 3,
            beatsWasHit: [true, false, false]
        )
        sut.presentEvaluateRhythm(response)
        XCTAssertFalse(spy.evaluateRhythmVM?.feedbackCorrect ?? true)
        XCTAssertFalse(spy.evaluateRhythmVM?.feedbackText.isEmpty ?? true)
    }

    // MARK: - presentNextPattern

    func test_presentNextPattern_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentNextPattern(RhythmModels.NextPattern.Response())
        XCTAssertTrue(spy.nextPatternCalled)
    }

    // MARK: - presentComplete

    func test_presentComplete_highScore_3stars() {
        let (sut, spy) = makeSUT()
        sut.presentComplete(RhythmModels.Complete.Response(finalScore: 0.95, correctPatterns: 5, totalPatterns: 5))
        XCTAssertEqual(spy.completeVM?.starsEarned, 3)
        XCTAssertFalse(spy.completeVM?.completionMessage.isEmpty ?? true)
        XCTAssertFalse(spy.completeVM?.scoreLabel.isEmpty ?? true)
    }

    func test_presentComplete_midScore_2stars() {
        let (sut, spy) = makeSUT()
        sut.presentComplete(RhythmModels.Complete.Response(finalScore: 0.75, correctPatterns: 4, totalPatterns: 5))
        XCTAssertEqual(spy.completeVM?.starsEarned, 2)
    }

    func test_presentComplete_lowScore_0stars() {
        let (sut, spy) = makeSUT()
        sut.presentComplete(RhythmModels.Complete.Response(finalScore: 0.2, correctPatterns: 1, totalPatterns: 5))
        XCTAssertEqual(spy.completeVM?.starsEarned, 0)
    }

    // MARK: - stars(for:) utility

    func test_stars_boundary_exactlyPoint9_returns3() {
        XCTAssertEqual(RhythmPresenter.stars(for: 0.9), 3)
    }

    func test_stars_boundary_exactlyPoint7_returns2() {
        XCTAssertEqual(RhythmPresenter.stars(for: 0.7), 2)
    }

    func test_stars_boundary_exactlyPoint5_returns1() {
        XCTAssertEqual(RhythmPresenter.stars(for: 0.5), 1)
    }
}
