@testable import HappySpeech
import XCTest

// MARK: - Spy Presenter

@MainActor
private final class SpyBreathingARPresenter: BreathingARPresentationLogic {
    var startGameCallCount = 0
    var updateFrameCallCount = 0
    var scoreCallCount = 0

    var lastStartGame: BreathingARModels.StartGame.Response?
    var lastUpdateFrame: BreathingARModels.UpdateFrame.Response?
    var lastScore: BreathingARModels.ScoreAttempt.Response?

    func presentStartGame(_ response: BreathingARModels.StartGame.Response) {
        startGameCallCount += 1
        lastStartGame = response
    }
    func presentUpdateFrame(_ response: BreathingARModels.UpdateFrame.Response) {
        updateFrameCallCount += 1
        lastUpdateFrame = response
    }
    func presentScoreAttempt(_ response: BreathingARModels.ScoreAttempt.Response) {
        scoreCallCount += 1
        lastScore = response
    }
}

// MARK: - Tests

@MainActor
final class BreathingARInteractorTests: XCTestCase {

    private func makeSUT() -> (BreathingARInteractor, SpyBreathingARPresenter) {
        let sut = BreathingARInteractor()
        let spy = SpyBreathingARPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    /// Blendshapes сильного выдоха (cheekPuff выше порога 0.25).
    private let blowingFace = FaceBlendshapes(cheekPuff: 0.9)
    /// Амплитуда микрофона выше порога 0.15.
    private let blowingAmplitude: Float = 0.8

    /// Отправляет N кадров выдоха.
    private func sendBlowFrames(_ sut: BreathingARInteractor, count: Int) {
        for _ in 0..<count {
            sut.updateFrame(.init(blendshapes: blowingFace, micAmplitude: blowingAmplitude))
        }
    }

    // MARK: - startGame

    func test_startGame_emitsDandelionCount() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(dandelionCount: 7))
        XCTAssertEqual(spy.startGameCallCount, 1)
        XCTAssertEqual(spy.lastStartGame?.dandelionCount, 7)
    }

    // MARK: - updateFrame: blowing detection

    func test_updateFrame_noBlow_isBlowingFalse() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(dandelionCount: 5))
        sut.updateFrame(.init(blendshapes: FaceBlendshapes(), micAmplitude: 0.0))
        XCTAssertEqual(spy.lastUpdateFrame?.isBlowing, false)
        XCTAssertEqual(spy.lastUpdateFrame?.strength, 0)
    }

    func test_updateFrame_sustainedBlow_becomesBlowing() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(dandelionCount: 5))
        // Нужно minSustainFrames (3) кадров подряд, чтобы isBlowing == true
        sendBlowFrames(sut, count: 5)
        XCTAssertEqual(spy.lastUpdateFrame?.isBlowing, true)
        XCTAssertGreaterThan(spy.lastUpdateFrame?.strength ?? 0, 0)
    }

    func test_updateFrame_blowThenStop_resetsBlowing() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(dandelionCount: 5))
        sendBlowFrames(sut, count: 5)
        XCTAssertEqual(spy.lastUpdateFrame?.isBlowing, true)
        // Останавливаем выдох — sustainCounter падает ниже порога
        for _ in 0..<5 {
            sut.updateFrame(.init(blendshapes: FaceBlendshapes(), micAmplitude: 0.0))
        }
        XCTAssertEqual(spy.lastUpdateFrame?.isBlowing, false)
    }

    func test_updateFrame_sustainedBlow_blowsDandelions() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(dandelionCount: 5))
        // 30 кадров выдоха сдувают один одуванчик; 5 одуванчиков → 150 кадров
        // updateFrame нужно достаточно кадров с учётом раскрутки счётчика.
        sendBlowFrames(sut, count: 200)
        // Все одуванчики сдуты → должен сработать scoreAttempt
        XCTAssertGreaterThanOrEqual(spy.scoreCallCount, 1)
    }

    // MARK: - scoreAttempt

    func test_scoreAttempt_perfect_threeStars() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(blownCount: 5, totalCount: 5))
        XCTAssertEqual(spy.lastScore?.stars, 3)
        XCTAssertEqual(spy.lastScore?.percent, 100)
    }

    func test_scoreAttempt_partial_twoStars() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(blownCount: 4, totalCount: 5))
        XCTAssertEqual(spy.lastScore?.stars, 2)
        XCTAssertEqual(spy.lastScore?.percent, 80)
    }

    func test_scoreAttempt_low_oneStar() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(blownCount: 1, totalCount: 5))
        XCTAssertEqual(spy.lastScore?.stars, 1)
        XCTAssertEqual(spy.lastScore?.percent, 20)
    }

    func test_scoreAttempt_zeroTotal_noDivisionByZero() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(blownCount: 0, totalCount: 0))
        XCTAssertEqual(spy.scoreCallCount, 1)
        XCTAssertEqual(spy.lastScore?.stars, 1)
    }

    func test_scoreAttempt_exactly60Percent_twoStars() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(blownCount: 3, totalCount: 5))
        XCTAssertEqual(spy.lastScore?.stars, 2)
    }

    // MARK: - full game flow

    func test_fullFlow_startThenBlowToComplete() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(dandelionCount: 1))
        XCTAssertEqual(spy.startGameCallCount, 1)
        sendBlowFrames(sut, count: 50)
        XCTAssertGreaterThanOrEqual(spy.scoreCallCount, 1)
        XCTAssertEqual(spy.lastScore?.stars, 3, "Один одуванчик сдут полностью")
    }
}
