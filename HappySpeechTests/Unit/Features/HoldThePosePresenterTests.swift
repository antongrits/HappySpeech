@testable import HappySpeech
import XCTest

// MARK: - HoldThePosePresenterTests
//
// Verifies the Response → ViewModel mapping in the AR "hold the pose"
// presenter. The presenter consumes plain Response structs (blendshapes live
// in the UpdateFrame Request), so it is unit-testable without ARKit:
//   - StartGame: postureName via ArticulationPosture.displayName;
//     holdTargetText formatted; hold target captured as state
//   - UpdateFrame: progress = min(1, held / capturedTarget) → clamps at 1;
//     confidence → integer percent
//   - UpdateFrame default target (5s) before StartGame is observed
//   - ScoreAttempt: result message formatted; stars carried

@MainActor
final class HoldThePosePresenterTests: XCTestCase {

    @MainActor
    private final class DisplaySpy: HoldThePoseDisplayLogic {
        var startVM: HoldThePoseModels.StartGame.ViewModel?
        var frameVM: HoldThePoseModels.UpdateFrame.ViewModel?
        var scoreVM: HoldThePoseModels.ScoreAttempt.ViewModel?

        func displayStartGame(_ viewModel: HoldThePoseModels.StartGame.ViewModel) { startVM = viewModel }
        func displayUpdateFrame(_ viewModel: HoldThePoseModels.UpdateFrame.ViewModel) { frameVM = viewModel }
        func displayScoreAttempt(_ viewModel: HoldThePoseModels.ScoreAttempt.ViewModel) { scoreVM = viewModel }
    }

    private func makeSUT() -> (HoldThePosePresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = HoldThePosePresenter()
        presenter.display = spy
        return (presenter, spy)
    }

    // MARK: - StartGame

    func test_startGame_postureNameAndHoldTarget() {
        let (sut, spy) = makeSUT()
        sut.presentStartGame(.init(targetPosture: .cupShape, holdDurationSec: 6))
        XCTAssertEqual(spy.startVM?.postureName, ArticulationPosture.cupShape.displayName)
        XCTAssertFalse(spy.startVM?.holdTargetText.isEmpty ?? true)
        XCTAssertTrue(spy.startVM?.holdTargetText.contains("6") ?? false)
    }

    // MARK: - UpdateFrame progress

    func test_updateFrame_progressHalfwayThroughTarget() {
        let (sut, spy) = makeSUT()
        sut.presentStartGame(.init(targetPosture: .smile, holdDurationSec: 10))
        sut.presentUpdateFrame(.init(confidence: 0.8, heldSeconds: 5))
        XCTAssertEqual(spy.frameVM?.progress ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(spy.frameVM?.confidencePercent, 80)
    }

    func test_updateFrame_progressClampedAtOne() {
        let (sut, spy) = makeSUT()
        sut.presentStartGame(.init(targetPosture: .smile, holdDurationSec: 4))
        sut.presentUpdateFrame(.init(confidence: 1.0, heldSeconds: 10)) // exceeds target
        XCTAssertEqual(spy.frameVM?.progress, 1)
        XCTAssertEqual(spy.frameVM?.confidencePercent, 100)
    }

    func test_updateFrame_defaultTargetFiveSecondsBeforeStart() {
        let (sut, spy) = makeSUT()
        // No StartGame yet → presenter's default holdTarget is 5s.
        sut.presentUpdateFrame(.init(confidence: 0.5, heldSeconds: 5))
        XCTAssertEqual(spy.frameVM?.progress, 1, "5s held over default 5s target → full progress")
        XCTAssertEqual(spy.frameVM?.confidencePercent, 50)
    }

    // MARK: - ScoreAttempt

    func test_score_carriesStarsAndMessage() {
        let (sut, spy) = makeSUT()
        sut.presentScoreAttempt(.init(stars: 2, heldSeconds: 4.5))
        XCTAssertEqual(spy.scoreVM?.stars, 2)
        XCTAssertFalse(spy.scoreVM?.message.isEmpty ?? true)
    }
}
