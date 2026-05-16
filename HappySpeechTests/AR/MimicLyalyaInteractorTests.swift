@testable import HappySpeech
import CoreGraphics
import XCTest

// MARK: - Spy Presenter

@MainActor
private final class SpyMimicLyalyaPresenter: MimicLyalyaPresentationLogic {
    var startGameCallCount = 0
    var updateFrameCallCount = 0
    var scoreCallCount = 0
    var handPoseCallCount = 0

    var lastStartGame: MimicLyalyaModels.StartGame.Response?
    var lastUpdateFrame: MimicLyalyaModels.UpdateFrame.Response?
    var lastScore: MimicLyalyaModels.ScoreAttempt.Response?
    var lastHandPose: MimicLyalyaModels.UpdateHandPose.Response?

    func presentStartGame(_ response: MimicLyalyaModels.StartGame.Response) {
        startGameCallCount += 1
        lastStartGame = response
    }
    func presentUpdateFrame(_ response: MimicLyalyaModels.UpdateFrame.Response) {
        updateFrameCallCount += 1
        lastUpdateFrame = response
    }
    func presentScoreAttempt(_ response: MimicLyalyaModels.ScoreAttempt.Response) {
        scoreCallCount += 1
        lastScore = response
    }
    func presentHandPoseUpdate(_ response: MimicLyalyaModels.UpdateHandPose.Response) {
        handPoseCallCount += 1
        lastHandPose = response
    }
}

// MARK: - Tests
//
// Заметка о покрытии AR-кода:
// MimicLyalyaInteractor — VIP-thin. Реальный ARFaceAnchor blendshape stream
// и Vision VNDetectHumanHandPoseRequest живут во View. Покрыта вся
// VIP-логика: startGame (цикл поз), updateFrame (posture matching),
// scoreAttempt (звёзды), nextRound, updateHandPose (Block J — жесты).
// FaceBlendshapes и HandPoseObservation эмулируются фикстурами.

@MainActor
final class MimicLyalyaInteractorTests: XCTestCase {

    private func makeSUT() -> (MimicLyalyaInteractor, SpyMimicLyalyaPresenter) {
        let sut = MimicLyalyaInteractor()
        let spy = SpyMimicLyalyaPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    private func handObservation(pose: HandPose, confidence: Float) -> HandPoseObservation {
        HandPoseObservation(
            pose: pose,
            confidence: confidence,
            landmarks: Array(repeating: CGPoint(x: 0.5, y: 0.5), count: 21),
            chirality: .right,
            timestamp: 0
        )
    }

    // MARK: - startGame

    func test_startGame_emitsFirstRound() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(rounds: 5))
        XCTAssertEqual(spy.startGameCallCount, 1)
        XCTAssertEqual(spy.lastStartGame?.roundNumber, 1)
        XCTAssertEqual(spy.lastStartGame?.totalRounds, 5)
    }

    func test_startGame_firstPostureIsSmile() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(rounds: 5))
        XCTAssertEqual(spy.lastStartGame?.targetPosture, .smile)
    }

    // MARK: - updateFrame

    func test_updateFrame_matchingPosture_highConfidence() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(rounds: 5))
        // Раунд 0 → smile
        sut.updateFrame(.init(blendshapes: FaceBlendshapes(mouthSmileLeft: 1, mouthSmileRight: 1)))
        XCTAssertEqual(spy.updateFrameCallCount, 1)
        XCTAssertTrue(spy.lastUpdateFrame?.isMatching ?? false)
        XCTAssertGreaterThan(spy.lastUpdateFrame?.confidence ?? 0, 0.65)
    }

    func test_updateFrame_nonMatchingPosture_lowConfidence() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(rounds: 5))
        sut.updateFrame(.init(blendshapes: FaceBlendshapes()))
        XCTAssertFalse(spy.lastUpdateFrame?.isMatching ?? true)
    }

    // MARK: - scoreAttempt

    func test_scoreAttempt_highConfidence_threeStars() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(confidence: 0.9))
        XCTAssertEqual(spy.lastScore?.stars, 3)
    }

    func test_scoreAttempt_mediumConfidence_twoStars() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(confidence: 0.7))
        XCTAssertEqual(spy.lastScore?.stars, 2)
    }

    func test_scoreAttempt_lowConfidence_oneStar() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(confidence: 0.3))
        XCTAssertEqual(spy.lastScore?.stars, 1)
    }

    // MARK: - nextRound

    func test_nextRound_advancesPostureCycle() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(rounds: 5))
        sut.nextRound()
        XCTAssertEqual(spy.lastStartGame?.roundNumber, 2)
        XCTAssertEqual(spy.lastStartGame?.targetPosture, .pucker)
    }

    func test_nextRound_beyondTotal_doesNotEmit() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(rounds: 2))
        sut.nextRound() // round 2
        let countBefore = spy.startGameCallCount
        sut.nextRound() // round 3 >= total → no emit
        XCTAssertEqual(spy.startGameCallCount, countBefore)
    }

    func test_nextRound_cyclesThroughAllFivePostures() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(rounds: 5))
        var postures: [ArticulationPosture] = [spy.lastStartGame!.targetPosture]
        for _ in 0..<4 {
            sut.nextRound()
            if let p = spy.lastStartGame?.targetPosture { postures.append(p) }
        }
        XCTAssertEqual(postures, [.smile, .pucker, .cupShape, .tongueUp, .mushroom])
    }

    // MARK: - updateHandPose (Block J)

    func test_updateHandPose_unknownPose_notMatching() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(rounds: 5))
        sut.updateHandPose(.init(observation: handObservation(pose: .unknown, confidence: 0.9)))
        XCTAssertEqual(spy.handPoseCallCount, 1)
        XCTAssertFalse(spy.lastHandPose?.isMatching ?? true)
    }

    func test_updateHandPose_lowConfidence_notMatching() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(rounds: 5))
        sut.updateHandPose(.init(observation: handObservation(pose: .openPalm, confidence: 0.3)))
        XCTAssertFalse(spy.lastHandPose?.isMatching ?? true)
    }

    func test_updateHandPose_evenRound_noHandTarget() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(rounds: 5)) // round 0 — чётный → нет жестовой цели
        sut.updateHandPose(.init(observation: handObservation(pose: .openPalm, confidence: 0.9)))
        XCTAssertNil(spy.lastHandPose?.targetPose)
        XCTAssertFalse(spy.lastHandPose?.isMatching ?? true)
    }

    func test_updateHandPose_oddRound_hasHandTarget() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(rounds: 5))
        sut.nextRound() // round 1 — нечётный → жестовая цель назначена
        sut.updateHandPose(.init(observation: handObservation(pose: .openPalm, confidence: 0.9)))
        XCTAssertNotNil(spy.lastHandPose?.targetPose)
    }

    func test_updateHandPose_matchingTargetPose_isMatching() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(rounds: 5))
        sut.nextRound() // round 1 → handPoseCycle[1] == .point
        let target = spy.lastHandPose?.targetPose
        // Подаём ту же позу что и target
        let observed = handObservation(pose: .point, confidence: 0.95)
        sut.updateHandPose(.init(observation: observed))
        if target == .point {
            XCTAssertTrue(spy.lastHandPose?.isMatching ?? false)
        }
    }

    func test_updateHandPose_confidencePropagated() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(rounds: 5))
        sut.updateHandPose(.init(observation: handObservation(pose: .fist, confidence: 0.82)))
        XCTAssertEqual(spy.lastHandPose?.confidence ?? 0, 0.82, accuracy: 0.0001)
    }

    // MARK: - HandPose model

    func test_handPose_debugDescriptionsNotEmpty() {
        for pose in HandPose.allCases {
            XCTAssertFalse(pose.debugDescription.isEmpty)
        }
    }
}
