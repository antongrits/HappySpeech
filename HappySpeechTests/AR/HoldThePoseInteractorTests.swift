@testable import HappySpeech
import XCTest

// MARK: - Spy Presenter

@MainActor
private final class SpyHoldThePosePresenter: HoldThePosePresentationLogic {
    var startGameCallCount = 0
    var updateFrameCallCount = 0
    var scoreCallCount = 0

    var lastStartGame: HoldThePoseModels.StartGame.Response?
    var lastUpdateFrame: HoldThePoseModels.UpdateFrame.Response?
    var lastScore: HoldThePoseModels.ScoreAttempt.Response?

    func presentStartGame(_ response: HoldThePoseModels.StartGame.Response) {
        startGameCallCount += 1
        lastStartGame = response
    }
    func presentUpdateFrame(_ response: HoldThePoseModels.UpdateFrame.Response) {
        updateFrameCallCount += 1
        lastUpdateFrame = response
    }
    func presentScoreAttempt(_ response: HoldThePoseModels.ScoreAttempt.Response) {
        scoreCallCount += 1
        lastScore = response
    }
}

// MARK: - Tests
//
// Заметка о покрытии AR-кода:
// HoldThePoseInteractor — VIP-thin. ARSCNViewDelegate frame stream живёт во
// View. Покрыта вся VIP-логика: startGame, updateFrame (hold timer reset/
// accumulation), scoreAttempt (звёздная шкала). Frame stream эмулируется
// через FaceBlendshapes; TonguePostureClassifier rule-based и детерминирован.
// Авто-завершение по достижению holdTarget зависит от wall-clock Date()
// внутри updateFrame — недостижимо синхронно в юните без time-инъекции;
// scoreAttempt тестируется напрямую (тот же путь scoring).

@MainActor
final class HoldThePoseInteractorTests: XCTestCase {

    private func makeSUT() -> (HoldThePoseInteractor, SpyHoldThePosePresenter) {
        let sut = HoldThePoseInteractor()
        let spy = SpyHoldThePosePresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - startGame

    func test_startGame_emitsTargetPostureAndDuration() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetPosture: .pucker, holdDurationSec: 4))
        XCTAssertEqual(spy.startGameCallCount, 1)
        XCTAssertEqual(spy.lastStartGame?.targetPosture, .pucker)
        XCTAssertEqual(spy.lastStartGame?.holdDurationSec, 4)
    }

    func test_startGame_resetsState() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetPosture: .smile, holdDurationSec: 5))
        sut.updateFrame(.init(blendshapes: FaceBlendshapes(mouthSmileLeft: 1, mouthSmileRight: 1)))
        sut.startGame(.init(targetPosture: .smile, holdDurationSec: 5))
        // После рестарта первый кадр без позы → 0 held
        sut.updateFrame(.init(blendshapes: FaceBlendshapes()))
        XCTAssertEqual(spy.lastUpdateFrame?.heldSeconds, 0)
    }

    // MARK: - updateFrame

    func test_updateFrame_lowConfidence_zeroHeld() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetPosture: .smile, holdDurationSec: 5))
        sut.updateFrame(.init(blendshapes: FaceBlendshapes()))
        XCTAssertEqual(spy.lastUpdateFrame?.heldSeconds, 0)
    }

    func test_updateFrame_highConfidence_startsHoldTimer() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetPosture: .smile, holdDurationSec: 5))
        sut.updateFrame(.init(blendshapes: FaceBlendshapes(mouthSmileLeft: 1, mouthSmileRight: 1)))
        XCTAssertGreaterThan(spy.lastUpdateFrame?.confidence ?? 0, 0.6)
        // held стартует с ~0 (только что начали)
        XCTAssertGreaterThanOrEqual(spy.lastUpdateFrame?.heldSeconds ?? -1, 0)
    }

    func test_updateFrame_dropConfidence_resetsHold() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetPosture: .smile, holdDurationSec: 5))
        sut.updateFrame(.init(blendshapes: FaceBlendshapes(mouthSmileLeft: 1, mouthSmileRight: 1)))
        sut.updateFrame(.init(blendshapes: FaceBlendshapes()))
        XCTAssertEqual(spy.lastUpdateFrame?.heldSeconds, 0)
    }

    func test_updateFrame_reportsConfidenceForTargetPosture() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetPosture: .pucker, holdDurationSec: 5))
        sut.updateFrame(.init(blendshapes: FaceBlendshapes(mouthPucker: 1.0)))
        XCTAssertGreaterThan(spy.lastUpdateFrame?.confidence ?? 0, 0.6)
    }

    // MARK: - scoreAttempt

    func test_scoreAttempt_highConfidence_threeStars() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(heldSeconds: 5, averageConfidence: 0.9))
        XCTAssertEqual(spy.lastScore?.stars, 3)
        XCTAssertEqual(spy.lastScore?.heldSeconds, 5)
    }

    func test_scoreAttempt_mediumConfidence_twoStars() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(heldSeconds: 4, averageConfidence: 0.75))
        XCTAssertEqual(spy.lastScore?.stars, 2)
    }

    func test_scoreAttempt_lowConfidence_oneStar() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(heldSeconds: 2, averageConfidence: 0.55))
        XCTAssertEqual(spy.lastScore?.stars, 1)
    }

    func test_scoreAttempt_veryLowConfidence_zeroStars() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(heldSeconds: 1, averageConfidence: 0.1))
        XCTAssertEqual(spy.lastScore?.stars, 0)
    }

    func test_scoreAttempt_boundary70_twoStars() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(heldSeconds: 3, averageConfidence: 0.7))
        XCTAssertEqual(spy.lastScore?.stars, 2)
    }

    func test_scoreAttempt_preservesHeldSeconds() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(heldSeconds: 7.5, averageConfidence: 0.9))
        XCTAssertEqual(spy.lastScore?.heldSeconds ?? -1, 7.5, accuracy: 0.001)
    }
}
