@testable import HappySpeech
import XCTest

// MARK: - Spy Presenter

@MainActor
private final class SpySoundAndFacePresenter: SoundAndFacePresentationLogic {
    var startGameCallCount = 0
    var updateFrameCallCount = 0
    var scoreCallCount = 0

    var lastStartGame: SoundAndFaceModels.StartGame.Response?
    var lastUpdateFrame: SoundAndFaceModels.UpdateFrame.Response?
    var lastScore: SoundAndFaceModels.ScoreAttempt.Response?

    func presentStartGame(_ response: SoundAndFaceModels.StartGame.Response) {
        startGameCallCount += 1
        lastStartGame = response
    }
    func presentUpdateFrame(_ response: SoundAndFaceModels.UpdateFrame.Response) {
        updateFrameCallCount += 1
        lastUpdateFrame = response
    }
    func presentScoreAttempt(_ response: SoundAndFaceModels.ScoreAttempt.Response) {
        scoreCallCount += 1
        lastScore = response
    }
}

// MARK: - Tests
//
// Заметка о покрытии AR-кода:
// SoundAndFaceInteractor — VIP-thin. ARFaceAnchor blendshapes + WhisperKit
// ASR транскрипция живут во View / ASRService. Покрыта вся VIP-логика:
// startGame (звук → поза), updateFrame (накопление posture confidence),
// scoreAttempt (комбинация ASR-совпадения и позы → звёзды). Транскрипт
// и blendshapes подаются как фикстуры.

@MainActor
final class SoundAndFaceInteractorTests: XCTestCase {

    private func makeSUT() -> (SoundAndFaceInteractor, SpySoundAndFacePresenter) {
        let sut = SoundAndFaceInteractor()
        let spy = SpySoundAndFacePresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - startGame

    func test_startGame_emitsTarget() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "С"))
        XCTAssertEqual(spy.startGameCallCount, 1)
        XCTAssertEqual(spy.lastStartGame?.target.sound, "С")
    }

    func test_startGame_mapsWhistlingToSmile() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "С"))
        XCTAssertEqual(spy.lastStartGame?.target.posture, .smile)
    }

    func test_startGame_mapsHissingToCupShape() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "Ш"))
        XCTAssertEqual(spy.lastStartGame?.target.posture, .cupShape)
    }

    func test_startGame_mapsRToMushroom() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "Р"))
        XCTAssertEqual(spy.lastStartGame?.target.posture, .mushroom)
    }

    func test_startGame_mapsLToTongueUp() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "Л"))
        XCTAssertEqual(spy.lastStartGame?.target.posture, .tongueUp)
    }

    func test_startGame_mapsVelarToShoveling() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "К"))
        XCTAssertEqual(spy.lastStartGame?.target.posture, .shoveling)
    }

    func test_startGame_unknownSound_mapsToNeutral() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "Щ"))
        XCTAssertEqual(spy.lastStartGame?.target.posture, .neutral)
    }

    func test_startGame_lowercaseSoundHandled() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "р"))
        XCTAssertEqual(spy.lastStartGame?.target.posture, .mushroom)
    }

    // MARK: - updateFrame

    func test_updateFrame_withoutStart_ignored() {
        let (sut, spy) = makeSUT()
        sut.updateFrame(.init(blendshapes: FaceBlendshapes()))
        XCTAssertEqual(spy.updateFrameCallCount, 0)
    }

    func test_updateFrame_afterStart_emitsConfidence() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "С"))
        sut.updateFrame(.init(blendshapes: FaceBlendshapes(mouthSmileLeft: 1, mouthSmileRight: 1)))
        XCTAssertEqual(spy.updateFrameCallCount, 1)
        XCTAssertGreaterThan(spy.lastUpdateFrame?.postureConfidence ?? 0, 0.6)
    }

    func test_updateFrame_lowConfidenceForWrongPosture() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "С")) // ждёт smile
        sut.updateFrame(.init(blendshapes: FaceBlendshapes()))
        XCTAssertLessThan(spy.lastUpdateFrame?.postureConfidence ?? 1, 0.6)
    }

    // MARK: - scoreAttempt

    func test_scoreAttempt_withoutStart_ignored() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(asrTranscript: "са", avgPostureConfidence: 0.9))
        XCTAssertEqual(spy.scoreCallCount, 0)
    }

    func test_scoreAttempt_matchedAndPosture_threeStars() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "С"))
        sut.scoreAttempt(.init(asrTranscript: "сссс", avgPostureConfidence: 0.8))
        XCTAssertEqual(spy.lastScore?.stars, 3)
        XCTAssertTrue(spy.lastScore?.transcriptMatched ?? false)
    }

    func test_scoreAttempt_matchedNoPosture_twoStars() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "С"))
        sut.scoreAttempt(.init(asrTranscript: "сок", avgPostureConfidence: 0.3))
        XCTAssertEqual(spy.lastScore?.stars, 2)
    }

    func test_scoreAttempt_postureNoMatch_twoStars() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "С"))
        sut.scoreAttempt(.init(asrTranscript: "мяу", avgPostureConfidence: 0.8))
        XCTAssertEqual(spy.lastScore?.stars, 2)
        XCTAssertFalse(spy.lastScore?.transcriptMatched ?? true)
    }

    func test_scoreAttempt_neitherMatched_oneStar() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "С"))
        sut.scoreAttempt(.init(asrTranscript: "мяу", avgPostureConfidence: 0.2))
        XCTAssertEqual(spy.lastScore?.stars, 1)
    }

    func test_scoreAttempt_caseInsensitiveMatch() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "С"))
        sut.scoreAttempt(.init(asrTranscript: "СУП", avgPostureConfidence: 0.7))
        XCTAssertTrue(spy.lastScore?.transcriptMatched ?? false)
    }

    func test_scoreAttempt_boundaryPostureConfidence60_counts() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "Р"))
        sut.scoreAttempt(.init(asrTranscript: "рак", avgPostureConfidence: 0.6))
        XCTAssertEqual(spy.lastScore?.stars, 3)
    }
}
