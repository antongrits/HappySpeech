@testable import HappySpeech
import XCTest

// MARK: - Spy Presenter

@MainActor
private final class SpyButterflyCatchPresenter: ButterflyCatchPresentationLogic {
    var startGameCallCount = 0
    var spawnCallCount = 0
    var scoreCallCount = 0

    var lastStartGame: ButterflyCatchModels.StartGame.Response?
    var spawnedButterflies: [ButterflyCatchModels.Butterfly] = []
    var lastScore: ButterflyCatchModels.ScoreAttempt.Response?

    func presentStartGame(_ response: ButterflyCatchModels.StartGame.Response) {
        startGameCallCount += 1
        lastStartGame = response
    }
    func presentSpawnButterfly(_ response: ButterflyCatchModels.SpawnButterfly.Response) {
        spawnCallCount += 1
        spawnedButterflies.append(response.butterfly)
    }
    func presentScoreAttempt(_ response: ButterflyCatchModels.ScoreAttempt.Response) {
        scoreCallCount += 1
        lastScore = response
    }
}

// MARK: - Tests

@MainActor
final class ButterflyCatchInteractorTests: XCTestCase {

    private func makeSUT() -> (ButterflyCatchInteractor, SpyButterflyCatchPresenter) {
        let sut = ButterflyCatchInteractor()
        let spy = SpyButterflyCatchPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    /// Blendshapes, гарантированно дающие confidence >= 0.6 для конкретной позы.
    private func blendshapes(for posture: ArticulationPosture) -> FaceBlendshapes {
        switch posture {
        case .smile:
            return FaceBlendshapes(mouthSmileLeft: 1.0, mouthSmileRight: 1.0)
        case .pucker:
            return FaceBlendshapes(mouthPucker: 1.0)
        case .cupShape:
            return FaceBlendshapes(mouthFunnel: 1.0)
        default:
            return FaceBlendshapes()
        }
    }

    // MARK: - startGame

    func test_startGame_emitsResponseWithDuration() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(durationSec: 120))
        XCTAssertEqual(spy.startGameCallCount, 1)
        XCTAssertEqual(spy.lastStartGame?.durationSec, 120)
        XCTAssertEqual(spy.lastStartGame?.totalButterflies, 0)
    }

    func test_startGame_resetsState() {
        let (sut, spy) = makeSUT()
        // Поймать одну бабочку
        sut.spawnButterfly(.init())
        guard let butterfly = spy.spawnedButterflies.first else { return XCTFail("Нет бабочки") }
        sut.scoreAttempt(.init(butterflyId: butterfly.id, blendshapes: blendshapes(for: butterfly.targetPosture)))
        XCTAssertEqual(spy.lastScore?.totalCaught, 1)
        // Рестарт должен обнулить счётчик
        sut.startGame(.init(durationSec: 60))
        sut.spawnButterfly(.init())
        guard let next = spy.spawnedButterflies.last else { return XCTFail("Нет бабочки") }
        sut.scoreAttempt(.init(butterflyId: next.id, blendshapes: blendshapes(for: next.targetPosture)))
        XCTAssertEqual(spy.lastScore?.totalCaught, 1, "totalCaught сброшен после startGame")
    }

    // MARK: - spawnButterfly

    func test_spawnButterfly_emitsButterflyInValidRange() {
        let (sut, spy) = makeSUT()
        sut.spawnButterfly(.init())
        XCTAssertEqual(spy.spawnCallCount, 1)
        guard let butterfly = spy.spawnedButterflies.first else { return XCTFail("Нет бабочки") }
        XCTAssertTrue((0.1...0.9).contains(butterfly.position.x))
        XCTAssertTrue((0.15...0.45).contains(butterfly.position.y))
        XCTAssertTrue([.smile, .pucker, .cupShape].contains(butterfly.targetPosture))
    }

    func test_spawnMultipleButterflies_uniqueIds() {
        let (sut, spy) = makeSUT()
        for _ in 0..<5 { sut.spawnButterfly(.init()) }
        let ids = Set(spy.spawnedButterflies.map(\.id))
        XCTAssertEqual(ids.count, 5, "Каждая бабочка имеет уникальный id")
    }

    // MARK: - scoreAttempt caught

    func test_scoreAttempt_correctPosture_caught() {
        let (sut, spy) = makeSUT()
        sut.spawnButterfly(.init())
        guard let butterfly = spy.spawnedButterflies.first else { return XCTFail("Нет бабочки") }
        sut.scoreAttempt(.init(butterflyId: butterfly.id, blendshapes: blendshapes(for: butterfly.targetPosture)))
        XCTAssertEqual(spy.lastScore?.caught, true)
        XCTAssertEqual(spy.lastScore?.totalCaught, 1)
    }

    func test_scoreAttempt_wrongPosture_notCaught() {
        let (sut, spy) = makeSUT()
        sut.spawnButterfly(.init())
        guard let butterfly = spy.spawnedButterflies.first else { return XCTFail("Нет бабочки") }
        // Нейтральное лицо — confidence для любой позы низкий
        sut.scoreAttempt(.init(butterflyId: butterfly.id, blendshapes: FaceBlendshapes()))
        XCTAssertEqual(spy.lastScore?.caught, false)
        XCTAssertEqual(spy.lastScore?.totalCaught, 0)
    }

    func test_scoreAttempt_unknownButterflyId_ignored() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(durationSec: 60))
        sut.scoreAttempt(.init(butterflyId: UUID(), blendshapes: FaceBlendshapes(mouthSmileLeft: 1, mouthSmileRight: 1)))
        XCTAssertEqual(spy.scoreCallCount, 0, "Неизвестная бабочка — без ответа")
    }

    func test_scoreAttempt_caughtButterflyRemoved_secondAttemptIgnored() {
        let (sut, spy) = makeSUT()
        sut.spawnButterfly(.init())
        guard let butterfly = spy.spawnedButterflies.first else { return XCTFail("Нет бабочки") }
        sut.scoreAttempt(.init(butterflyId: butterfly.id, blendshapes: blendshapes(for: butterfly.targetPosture)))
        let countAfterCatch = spy.scoreCallCount
        // Та же бабочка уже удалена из activeButterflies
        sut.scoreAttempt(.init(butterflyId: butterfly.id, blendshapes: blendshapes(for: butterfly.targetPosture)))
        XCTAssertEqual(spy.scoreCallCount, countAfterCatch, "Пойманная бабочка больше не активна")
    }

    func test_scoreAttempt_accumulatesAcrossButterflies() {
        let (sut, spy) = makeSUT()
        for _ in 0..<3 {
            sut.spawnButterfly(.init())
            guard let butterfly = spy.spawnedButterflies.last else { return XCTFail("Нет бабочки") }
            sut.scoreAttempt(.init(butterflyId: butterfly.id, blendshapes: blendshapes(for: butterfly.targetPosture)))
        }
        XCTAssertEqual(spy.lastScore?.totalCaught, 3)
    }

    func test_scoreAttempt_missThenHit_onlyCountsHit() {
        let (sut, spy) = makeSUT()
        sut.spawnButterfly(.init())
        guard let butterfly = spy.spawnedButterflies.first else { return XCTFail("Нет бабочки") }
        sut.scoreAttempt(.init(butterflyId: butterfly.id, blendshapes: FaceBlendshapes()))
        XCTAssertEqual(spy.lastScore?.totalCaught, 0)
        sut.scoreAttempt(.init(butterflyId: butterfly.id, blendshapes: blendshapes(for: butterfly.targetPosture)))
        XCTAssertEqual(spy.lastScore?.totalCaught, 1)
    }
}
