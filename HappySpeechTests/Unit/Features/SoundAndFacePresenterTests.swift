@testable import HappySpeech
import XCTest

// MARK: - SoundAndFacePresenterTests
//
// Verifies the Response → ViewModel mapping in the AR "say the sound, hold
// the face" presenter. The presenter consumes plain Response structs
// (blendshapes / ASR transcript live in Requests), so it is unit-testable
// without ARKit:
//   - StartGame: soundText from target.sound; postureName via displayName;
//     instruction non-empty
//   - UpdateFrame: postureConfidence forwarded as postureProgress
//   - ScoreAttempt: feedback key switches on transcriptMatched; stars carried

@MainActor
final class SoundAndFacePresenterTests: XCTestCase {

    @MainActor
    private final class DisplaySpy: SoundAndFaceDisplayLogic {
        var startVM: SoundAndFaceModels.StartGame.ViewModel?
        var frameVM: SoundAndFaceModels.UpdateFrame.ViewModel?
        var scoreVM: SoundAndFaceModels.ScoreAttempt.ViewModel?

        func displayStartGame(_ viewModel: SoundAndFaceModels.StartGame.ViewModel) { startVM = viewModel }
        func displayUpdateFrame(_ viewModel: SoundAndFaceModels.UpdateFrame.ViewModel) { frameVM = viewModel }
        func displayScoreAttempt(_ viewModel: SoundAndFaceModels.ScoreAttempt.ViewModel) { scoreVM = viewModel }
    }

    private func makeSUT() -> (SoundAndFacePresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = SoundAndFacePresenter()
        presenter.display = spy
        return (presenter, spy)
    }

    // MARK: - StartGame

    func test_startGame_routesSoundAndPosture() {
        let (sut, spy) = makeSUT()
        sut.presentStartGame(.init(target: .init(sound: "Р", posture: .tongueUp)))
        XCTAssertEqual(spy.startVM?.soundText, "Р")
        XCTAssertEqual(spy.startVM?.postureName, ArticulationPosture.tongueUp.displayName)
        XCTAssertFalse(spy.startVM?.instruction.isEmpty ?? true)
    }

    // MARK: - UpdateFrame

    func test_updateFrame_forwardsConfidenceAsProgress() {
        let (sut, spy) = makeSUT()
        sut.presentUpdateFrame(.init(postureConfidence: 0.65))
        XCTAssertEqual(spy.frameVM?.postureProgress, 0.65)
    }

    // MARK: - ScoreAttempt feedback branch

    func test_score_matched_feedbackDiffersFromMissed() {
        let (sut, spy) = makeSUT()
        sut.presentScoreAttempt(.init(stars: 3, transcriptMatched: true))
        let matched = spy.scoreVM?.feedback
        sut.presentScoreAttempt(.init(stars: 0, transcriptMatched: false))
        let missed = spy.scoreVM?.feedback
        XCTAssertNotNil(matched)
        XCTAssertNotNil(missed)
        XCTAssertNotEqual(matched, missed, "Совпадение/несовпадение транскрипта → разный фидбек")
    }

    func test_score_carriesStars() {
        let (sut, spy) = makeSUT()
        sut.presentScoreAttempt(.init(stars: 2, transcriptMatched: true))
        XCTAssertEqual(spy.scoreVM?.stars, 2)
        XCTAssertFalse(spy.scoreVM?.feedback.isEmpty ?? true)
    }
}
