import XCTest
@testable import HappySpeech

// MARK: - MimicLyalyaPresenterTests
//
// Phase 2.6 batch 3 — покрытие MimicLyalyaPresenter (14% → цель ≥90%).

@MainActor
final class MimicLyalyaPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: MimicLyalyaDisplayLogic {
        var startGameVM: MimicLyalyaModels.StartGame.ViewModel?
        var updateFrameVM: MimicLyalyaModels.UpdateFrame.ViewModel?
        var scoreVM: MimicLyalyaModels.ScoreAttempt.ViewModel?
        var handPoseVM: MimicLyalyaModels.UpdateHandPose.ViewModel?

        func displayStartGame(_ viewModel: MimicLyalyaModels.StartGame.ViewModel) { startGameVM = viewModel }
        func displayUpdateFrame(_ viewModel: MimicLyalyaModels.UpdateFrame.ViewModel) { updateFrameVM = viewModel }
        func displayScoreAttempt(_ viewModel: MimicLyalyaModels.ScoreAttempt.ViewModel) { scoreVM = viewModel }
        func displayHandPoseUpdate(_ viewModel: MimicLyalyaModels.UpdateHandPose.ViewModel) { handPoseVM = viewModel }
    }

    private func makeSUT() -> (MimicLyalyaPresenter, DisplaySpy) {
        let sut = MimicLyalyaPresenter()
        let spy = DisplaySpy()
        sut.display = spy
        return (sut, spy)
    }

    // MARK: - presentStartGame

    func test_presentStartGame_postureNameNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentStartGame(.init(targetPosture: .smile, roundNumber: 1, totalRounds: 5))
        XCTAssertNotNil(spy.startGameVM)
        XCTAssertFalse(spy.startGameVM?.postureName.isEmpty ?? true)
        XCTAssertFalse(spy.startGameVM?.mascotHint.isEmpty ?? true)
    }

    func test_presentStartGame_roundText_formattedCorrectly() {
        let (sut, spy) = makeSUT()
        sut.presentStartGame(.init(targetPosture: .pucker, roundNumber: 3, totalRounds: 5))
        // Ожидаем формат "3 / 5"
        XCTAssertEqual(spy.startGameVM?.roundText, "3 / 5")
    }

    func test_presentStartGame_allPostures_postureNameNotEmpty() {
        let (sut, spy) = makeSUT()
        let postures: [ArticulationPosture] = [.smile, .pucker, .cupShape, .tongueDown, .shoveling]
        for posture in postures {
            sut.presentStartGame(.init(targetPosture: posture, roundNumber: 1, totalRounds: 3))
            XCTAssertFalse(spy.startGameVM?.postureName.isEmpty ?? true, "Posture \(posture) must have non-empty name")
        }
    }

    // MARK: - presentUpdateFrame

    func test_presentUpdateFrame_matching_partyEmoji() {
        let (sut, spy) = makeSUT()
        sut.presentUpdateFrame(.init(confidence: 0.9, isMatching: true))
        XCTAssertNotNil(spy.updateFrameVM)
        XCTAssertEqual(spy.updateFrameVM?.emoji, "party.popper.fill")
        XCTAssertEqual(spy.updateFrameVM?.progress ?? 0, Float(0.9), accuracy: Float(0.01))
    }

    func test_presentUpdateFrame_notMatching_smilingEmoji() {
        let (sut, spy) = makeSUT()
        sut.presentUpdateFrame(.init(confidence: 0.2, isMatching: false))
        XCTAssertEqual(spy.updateFrameVM?.emoji, "face.smiling")
        XCTAssertEqual(spy.updateFrameVM?.progress ?? 0, Float(0.2), accuracy: Float(0.01))
    }

    func test_presentUpdateFrame_zeroConfidence_smilingEmoji() {
        let (sut, spy) = makeSUT()
        sut.presentUpdateFrame(.init(confidence: 0.0, isMatching: false))
        XCTAssertEqual(spy.updateFrameVM?.progress ?? 0, Float(0.0), accuracy: Float(0.01))
        XCTAssertEqual(spy.updateFrameVM?.emoji, "face.smiling")
    }

    // MARK: - presentScoreAttempt

    func test_presentScoreAttempt_starsPassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentScoreAttempt(.init(stars: 3))
        XCTAssertEqual(spy.scoreVM?.stars, 3)
        XCTAssertFalse(spy.scoreVM?.message.isEmpty ?? true)
    }

    func test_presentScoreAttempt_zeroStars_messageNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentScoreAttempt(.init(stars: 0))
        XCTAssertEqual(spy.scoreVM?.stars, 0)
        XCTAssertFalse(spy.scoreVM?.message.isEmpty ?? true)
    }

    // MARK: - presentHandPoseUpdate

    func test_presentHandPoseUpdate_matchingWithTarget_matchedHintKey() {
        let (sut, spy) = makeSUT()
        sut.presentHandPoseUpdate(.init(
            detectedPose: .openPalm,
            targetPose: .openPalm,
            isMatching: true,
            confidence: 0.9
        ))
        XCTAssertNotNil(spy.handPoseVM)
        XCTAssertEqual(spy.handPoseVM?.hintKey, "hand_pose.detect.matched")
        XCTAssertTrue(spy.handPoseVM?.isMatching == true)
        XCTAssertEqual(spy.handPoseVM?.poseNameKey, "hand_pose.open_palm")
    }

    func test_presentHandPoseUpdate_notMatchingWithTarget_detectHintKey() {
        let (sut, spy) = makeSUT()
        sut.presentHandPoseUpdate(.init(
            detectedPose: .fist,
            targetPose: .openPalm,
            isMatching: false,
            confidence: 0.2
        ))
        XCTAssertEqual(spy.handPoseVM?.hintKey, "hand_pose.detect.hint")
        XCTAssertFalse(spy.handPoseVM?.isMatching ?? true)
        // poseNameKey для targetPose = openPalm
        XCTAssertEqual(spy.handPoseVM?.poseNameKey, "hand_pose.open_palm")
    }

    func test_presentHandPoseUpdate_nilTarget_usesDetectedPose() {
        let (sut, spy) = makeSUT()
        sut.presentHandPoseUpdate(.init(
            detectedPose: .thumbsUp,
            targetPose: nil,
            isMatching: false,
            confidence: 0.5
        ))
        XCTAssertEqual(spy.handPoseVM?.hintKey, "hand_pose.detect.hint")
        XCTAssertEqual(spy.handPoseVM?.poseNameKey, "hand_pose.thumbs_up")
    }

    func test_presentHandPoseUpdate_allPoses_poseNameKeyNotEmpty() {
        let (sut, spy) = makeSUT()
        let poses: [HandPose] = [.openPalm, .fist, .point, .pinch, .wave, .thumbsUp, .unknown]
        let expectedKeys = [
            "hand_pose.open_palm",
            "hand_pose.fist",
            "hand_pose.point",
            "hand_pose.pinch",
            "hand_pose.wave",
            "hand_pose.thumbs_up",
            "hand_pose.detect.hint"
        ]
        for (pose, expectedKey) in zip(poses, expectedKeys) {
            sut.presentHandPoseUpdate(.init(
                detectedPose: pose,
                targetPose: nil,
                isMatching: false,
                confidence: 0.0
            ))
            XCTAssertEqual(spy.handPoseVM?.poseNameKey, expectedKey, "Pose \(pose) wrong key")
        }
    }
}
