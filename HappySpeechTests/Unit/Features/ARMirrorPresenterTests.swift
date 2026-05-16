import XCTest
@testable import HappySpeech

// MARK: - ARMirrorPresenterTests
//
// Phase 2.6 batch 3 — покрытие ARMirrorPresenter (37% → цель ≥90%).

@MainActor
final class ARMirrorPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: ARMirrorDisplayLogic {
        var startGameVM: ARMirrorModels.StartGame.ViewModel?
        var updateFrameVM: ARMirrorModels.UpdateFrame.ViewModel?
        var scoreVM: ARMirrorModels.ScoreAttempt.ViewModel?

        func displayStartGame(_ viewModel: ARMirrorModels.StartGame.ViewModel) { startGameVM = viewModel }
        func displayUpdateFrame(_ viewModel: ARMirrorModels.UpdateFrame.ViewModel) { updateFrameVM = viewModel }
        func displayScoreAttempt(_ viewModel: ARMirrorModels.ScoreAttempt.ViewModel) { scoreVM = viewModel }
    }

    private func makeSUT() -> (ARMirrorPresenter, DisplaySpy) {
        let sut = ARMirrorPresenter()
        let spy = DisplaySpy()
        sut.display = spy
        return (sut, spy)
    }

    // MARK: - presentStartGame

    func test_presentStartGame_validIndex_callsDisplay() {
        let (sut, spy) = makeSUT()
        let exercises: [ARMirrorModels.Exercise] = [.smile, .pucker, .funnel]
        sut.presentStartGame(.init(exercises: exercises, currentIndex: 0))
        XCTAssertNotNil(spy.startGameVM)
        XCTAssertEqual(spy.startGameVM?.currentExercise, .smile)
        XCTAssertEqual(spy.startGameVM?.exerciseNumber, 1)
        XCTAssertEqual(spy.startGameVM?.totalExercises, 3)
        XCTAssertFalse(spy.startGameVM?.instruction.isEmpty ?? true)
    }

    func test_presentStartGame_secondExercise_exerciseNumberIs2() {
        let (sut, spy) = makeSUT()
        let exercises: [ARMirrorModels.Exercise] = [.smile, .pucker, .funnel]
        sut.presentStartGame(.init(exercises: exercises, currentIndex: 1))
        XCTAssertEqual(spy.startGameVM?.currentExercise, .pucker)
        XCTAssertEqual(spy.startGameVM?.exerciseNumber, 2)
    }

    func test_presentStartGame_invalidIndex_displayNotCalled() {
        let (sut, spy) = makeSUT()
        // currentIndex за пределами массива → guard срабатывает → display не вызывается
        let exercises: [ARMirrorModels.Exercise] = [.smile]
        sut.presentStartGame(.init(exercises: exercises, currentIndex: 5))
        XCTAssertNil(spy.startGameVM)
    }

    func test_presentStartGame_emptyExercises_displayNotCalled() {
        let (sut, spy) = makeSUT()
        sut.presentStartGame(.init(exercises: [], currentIndex: 0))
        XCTAssertNil(spy.startGameVM)
    }

    func test_presentStartGame_allExercises_callsDisplay() {
        let (sut, spy) = makeSUT()
        for (idx, exercise) in ARMirrorModels.Exercise.allCases.enumerated() {
            let exercises = [exercise]
            sut.presentStartGame(.init(exercises: exercises, currentIndex: 0))
            XCTAssertEqual(spy.startGameVM?.currentExercise, exercise, "Exercise \(idx) must be set")
        }
    }

    // MARK: - presentUpdateFrame

    func test_presentUpdateFrame_highConfidence_hintFalse() {
        let (sut, spy) = makeSUT()
        sut.presentUpdateFrame(.init(
            currentExercise: .smile,
            confidence: 0.8,
            sustainedSeconds: 1.5,
            didCompleteExercise: false
        ))
        XCTAssertNotNil(spy.updateFrameVM)
        XCTAssertFalse(spy.updateFrameVM?.hintPulse ?? true)
        XCTAssertFalse(spy.updateFrameVM?.shouldAdvance ?? true)
    }

    func test_presentUpdateFrame_lowConfidence_hintTrue() {
        let (sut, spy) = makeSUT()
        sut.presentUpdateFrame(.init(
            currentExercise: .funnel,
            confidence: 0.1,
            sustainedSeconds: 0.0,
            didCompleteExercise: false
        ))
        XCTAssertTrue(spy.updateFrameVM?.hintPulse == true)
    }

    func test_presentUpdateFrame_exactThreshold03_hintFalse() {
        // confidence == 0.3 → NOT < 0.3 → hint = false
        let (sut, spy) = makeSUT()
        sut.presentUpdateFrame(.init(
            currentExercise: .jawOpen,
            confidence: 0.3,
            sustainedSeconds: 1.0,
            didCompleteExercise: false
        ))
        XCTAssertFalse(spy.updateFrameVM?.hintPulse ?? true)
    }

    func test_presentUpdateFrame_completedExercise_shouldAdvanceTrue() {
        let (sut, spy) = makeSUT()
        sut.presentUpdateFrame(.init(
            currentExercise: .tongueOut,
            confidence: 0.9,
            sustainedSeconds: 3.5,
            didCompleteExercise: true
        ))
        XCTAssertTrue(spy.updateFrameVM?.shouldAdvance == true)
    }

    func test_presentUpdateFrame_progressCapped() {
        let (sut, spy) = makeSUT()
        // sustainedSeconds=6 → 6/3=2.0, но capped at 1.0
        sut.presentUpdateFrame(.init(
            currentExercise: .smile,
            confidence: 1.0,
            sustainedSeconds: 6.0,
            didCompleteExercise: false
        ))
        XCTAssertEqual(spy.updateFrameVM?.progress ?? 0, 1.0, accuracy: 0.01)
    }

    func test_presentUpdateFrame_halfProgress() {
        let (sut, spy) = makeSUT()
        sut.presentUpdateFrame(.init(
            currentExercise: .pucker,
            confidence: 0.5,
            sustainedSeconds: 1.5,
            didCompleteExercise: false
        ))
        // 1.5/3.0 = 0.5
        XCTAssertEqual(spy.updateFrameVM?.progress ?? 0, 0.5, accuracy: 0.01)
    }

    // MARK: - presentScoreAttempt

    func test_presentScoreAttempt_3stars_excellentMessage() {
        let (sut, spy) = makeSUT()
        sut.presentScoreAttempt(.init(stars: 3))
        XCTAssertEqual(spy.scoreVM?.stars, 3)
        XCTAssertFalse(spy.scoreVM?.message.isEmpty ?? true)
    }

    func test_presentScoreAttempt_2stars_goodMessage() {
        let (sut, spy) = makeSUT()
        sut.presentScoreAttempt(.init(stars: 2))
        XCTAssertEqual(spy.scoreVM?.stars, 2)
        XCTAssertFalse(spy.scoreVM?.message.isEmpty ?? true)
    }

    func test_presentScoreAttempt_1star_tryAgainMessage() {
        let (sut, spy) = makeSUT()
        sut.presentScoreAttempt(.init(stars: 1))
        XCTAssertEqual(spy.scoreVM?.stars, 1)
        XCTAssertFalse(spy.scoreVM?.message.isEmpty ?? true)
    }

    func test_presentScoreAttempt_0stars_keepGoingMessage() {
        let (sut, spy) = makeSUT()
        sut.presentScoreAttempt(.init(stars: 0))
        XCTAssertEqual(spy.scoreVM?.stars, 0)
        XCTAssertFalse(spy.scoreVM?.message.isEmpty ?? true)
    }

    func test_presentScoreAttempt_differentStarCounts_differentMessages() {
        let (sut, _) = makeSUT()
        var messages = Set<String>()
        for stars in 0...3 {
            let localSpy = DisplaySpy()
            sut.display = localSpy
            sut.presentScoreAttempt(.init(stars: stars))
            if let msg = localSpy.scoreVM?.message {
                messages.insert(msg)
            }
        }
        // Все 4 уровня должны давать разные сообщения
        XCTAssertEqual(messages.count, 4)
    }
}
