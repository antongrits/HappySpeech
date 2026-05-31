@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubDetectiveWorker: ComprehensionDetectiveWorkerProtocol {
    var response: ComprehensionDetectiveModels.Start.Response
    private(set) var buildCallCount = 0
    private(set) var lastPreferredTier: GrammarTier?
    private(set) var voiceCallCount = 0
    private(set) var lastVoiceWasSlow = false

    init(response: ComprehensionDetectiveModels.Start.Response) {
        self.response = response
    }

    func buildSession(
        childId: String,
        preferredTier: GrammarTier?
    ) async -> ComprehensionDetectiveModels.Start.Response {
        buildCallCount += 1
        lastPreferredTier = preferredTier
        return response
    }

    func voiceInstruction(_ text: String, slowly: Bool) async {
        voiceCallCount += 1
        lastVoiceWasSlow = slowly
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyDetectivePresenter:
    ComprehensionDetectivePresentationLogic, @unchecked Sendable {
    var startCount = 0
    var pickCount = 0
    var lastPick: ComprehensionDetectiveModels.Pick.Response?

    func presentStart(response: ComprehensionDetectiveModels.Start.Response) async {
        startCount += 1
    }
    func presentPick(response: ComprehensionDetectiveModels.Pick.Response) async {
        pickCount += 1
        lastPick = response
    }
}

// MARK: - Spy AdaptivePlanner

private final class SpyDetectivePlanner: AdaptivePlannerService, @unchecked Sendable {
    private let lock = NSLock()
    private var _recordCount = 0
    private var _lastSound: String?
    private var _lastQuality: SM2Quality?

    var recordCount: Int { lock.withLock { _recordCount } }
    var lastSound: String? { lock.withLock { _lastSound } }
    var lastQuality: SM2Quality? { lock.withLock { _lastQuality } }

    func buildDailyRoute(for childId: String) async throws -> AdaptiveRoute {
        AdaptiveRoute(steps: [], maxDurationSec: 600, fatigueLevel: .normal)
    }
    func recordCompletion(sessionId: String, route: AdaptiveRoute) async throws {}
    func recordSessionResult(
        childId: String,
        soundTarget: String,
        qualityScore: SM2Quality
    ) async throws {
        lock.withLock {
            _recordCount += 1
            _lastSound = soundTarget
            _lastQuality = qualityScore
        }
    }
    func shouldTakeBreak(consecutiveWrong: Int, sessionDurationSec: Int, childAge: Int) -> Bool {
        false
    }
}

// MARK: - Fixtures

@MainActor
private func makeItem(
    id: String,
    tier: GrammarTier = .simple,
    correctSymbol: String = "soccerball",
    minAge: Int = 5
) -> DetectiveItem {
    let pictures = [
        DetectivePicture(id: "\(id)-\(correctSymbol)", symbolName: correctSymbol, label: "правильный"),
        DetectivePicture(id: "\(id)-car.fill", symbolName: "car.fill", label: "машина"),
        DetectivePicture(id: "\(id)-leaf.fill", symbolName: "leaf.fill", label: "лист"),
        DetectivePicture(id: "\(id)-house.fill", symbolName: "house.fill", label: "дом")
    ]
    return DetectiveItem(
        id: id, tier: tier, instruction: "Покажи мяч",
        pictures: pictures, correctPictureId: pictures[0].id, minAge: minAge
    )
}

@MainActor
private func makeRound(id: String, tier: GrammarTier = .simple) -> DetectiveRound {
    let item = makeItem(id: id, tier: tier)
    return DetectiveRound(id: "\(id)#round", item: item, shuffledPictures: item.pictures)
}

@MainActor
private func makeResponse(
    rounds: [DetectiveRound],
    soundTarget: String = "понимание речи",
    childAge: Int = 6,
    leadTier: GrammarTier = .simple
) -> ComprehensionDetectiveModels.Start.Response {
    .init(rounds: rounds, soundTarget: soundTarget, childAge: childAge, leadTier: leadTier)
}

/// id правильной картинки раунда.
@MainActor
private func correctId(_ round: DetectiveRound) -> String { round.item.correctPictureId }

/// id любого дистрактора раунда (для промаха).
@MainActor
private func wrongId(_ round: DetectiveRound) -> String {
    round.shuffledPictures.first { $0.id != round.item.correctPictureId }?.id ?? "bogus"
}

// MARK: - Interactor Tests

@MainActor
final class ComprehensionDetectiveInteractorTests: XCTestCase {

    private func makeSUT(
        rounds: [DetectiveRound],
        soundTarget: String = "понимание речи",
        childAge: Int = 6,
        leadTier: GrammarTier = .simple
    ) -> (ComprehensionDetectiveInteractor, SpyDetectivePresenter, StubDetectiveWorker, SpyHapticService, SpyDetectivePlanner) {
        let worker = StubDetectiveWorker(
            response: makeResponse(rounds: rounds, soundTarget: soundTarget, childAge: childAge, leadTier: leadTier)
        )
        let haptic = SpyHapticService()
        let planner = SpyDetectivePlanner()
        let sut = ComprehensionDetectiveInteractor(
            childId: "child-1", worker: worker,
            hapticService: haptic, adaptivePlanner: planner
        )
        let spy = SpyDetectivePresenter()
        sut.presenter = spy
        return (sut, spy, worker, haptic, planner)
    }

    // MARK: Start

    func test_start_buildsSessionAndPresents() async {
        let (sut, spy, worker, _, _) = makeSUT(rounds: [makeRound(id: "i1"), makeRound(id: "i2")])
        await sut.start(request: .init(childId: "child-1", preferredTier: nil))
        XCTAssertEqual(worker.buildCallCount, 1)
        XCTAssertEqual(spy.startCount, 1)
        XCTAssertEqual(sut.rounds.count, 2)
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
        XCTAssertEqual(sut.attemptsInRound, 0)
    }

    func test_start_voicesFirstInstruction() async {
        let (sut, _, worker, _, _) = makeSUT(rounds: [makeRound(id: "i1")])
        await sut.start(request: .init(childId: "child-1", preferredTier: nil))
        // Озвучка идёт в detached Task — даём ей выполниться.
        await Task.yield()
        await Task.yield()
        XCTAssertGreaterThanOrEqual(worker.voiceCallCount, 1)
    }

    func test_start_resetsProgress() async {
        let (sut, _, _, _, _) = makeSUT(rounds: [makeRound(id: "i1"), makeRound(id: "i2")])
        await sut.start(request: .init(childId: "child-1", preferredTier: nil))
        let r0 = sut.rounds[0]
        await sut.pick(request: .init(pictureId: correctId(r0), attemptInRound: 1))
        await sut.start(request: .init(childId: "child-1", preferredTier: nil))
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
    }

    func test_start_passesPreferredTierToWorker() async {
        let (sut, _, worker, _, _) = makeSUT(rounds: [makeRound(id: "i1")])
        await sut.start(request: .init(childId: "child-1", preferredTier: .withPreposition))
        XCTAssertEqual(worker.lastPreferredTier, .withPreposition)
    }

    // MARK: Picture evaluation («светофор»)

    func test_pick_correct_isHit_andIncrements() async {
        let (sut, spy, _, haptic, _) = makeSUT(rounds: [makeRound(id: "i1"), makeRound(id: "i2")])
        await sut.start(request: .init(childId: "child-1", preferredTier: nil))
        let r0 = sut.rounds[0]
        await sut.pick(request: .init(pictureId: correctId(r0), attemptInRound: 1))
        XCTAssertEqual(sut.correctCount, 1)
        XCTAssertEqual(spy.lastPick?.feedback, .hit)
        XCTAssertEqual(spy.lastPick?.correctPictureId, correctId(r0))
        XCTAssertEqual(haptic.notificationCount, 1)
        XCTAssertTrue(spy.lastPick?.advancedToNextRound ?? false)
    }

    func test_pick_firstMiss_isAlmost_doesNotAdvance() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeRound(id: "i1"), makeRound(id: "i2")])
        await sut.start(request: .init(childId: "child-1", preferredTier: nil))
        let r0 = sut.rounds[0]
        await sut.pick(request: .init(pictureId: wrongId(r0), attemptInRound: 1))
        XCTAssertEqual(spy.lastPick?.feedback, .almost)
        XCTAssertEqual(sut.correctCount, 0)
        XCTAssertEqual(sut.currentIndex, 0, "Первый промах не продвигает раунд")
        XCTAssertFalse(spy.lastPick?.advancedToNextRound ?? true)
        XCTAssertFalse(spy.lastPick?.showHint ?? true)
        XCTAssertTrue(spy.lastPick?.replaySlowly ?? false, "Промах → переозвучить инструкцию")
    }

    func test_pick_secondMiss_isRetry_showsHint_andAdvances() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeRound(id: "i1"), makeRound(id: "i2")])
        await sut.start(request: .init(childId: "child-1", preferredTier: nil))
        let r0 = sut.rounds[0]
        await sut.pick(request: .init(pictureId: wrongId(r0), attemptInRound: 1))
        await sut.pick(request: .init(pictureId: wrongId(r0), attemptInRound: 2))
        XCTAssertEqual(spy.lastPick?.feedback, .retry)
        XCTAssertTrue(spy.lastPick?.showHint ?? false, "После 2 промахов — подсказка")
        XCTAssertTrue(spy.lastPick?.advancedToNextRound ?? false, "Errorless: мягко идём дальше")
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(sut.attemptsInRound, 0, "Счётчик попыток сброшен на новом раунде")
    }

    func test_pick_hint_revealsCorrectPicture() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeRound(id: "i1"), makeRound(id: "i2")])
        await sut.start(request: .init(childId: "child-1", preferredTier: nil))
        let r0 = sut.rounds[0]
        await sut.pick(request: .init(pictureId: wrongId(r0), attemptInRound: 1))
        await sut.pick(request: .init(pictureId: wrongId(r0), attemptInRound: 2))
        // showHint == true, и Presenter подсветит correctPictureId.
        XCTAssertTrue(spy.lastPick?.showHint ?? false)
        XCTAssertEqual(spy.lastPick?.correctPictureId, correctId(r0))
    }

    func test_pick_neverProducesWrongTier() async {
        // Методика: только hit/almost/retry — никакого «неправильно».
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeRound(id: "i1"), makeRound(id: "i2")])
        await sut.start(request: .init(childId: "child-1", preferredTier: nil))
        let r0 = sut.rounds[0]
        await sut.pick(request: .init(pictureId: wrongId(r0), attemptInRound: 1))
        let tier1 = spy.lastPick?.feedback
        await sut.pick(request: .init(pictureId: wrongId(r0), attemptInRound: 2))
        let tier2 = spy.lastPick?.feedback
        XCTAssertEqual(tier1, .almost)
        XCTAssertEqual(tier2, .retry)
        XCTAssertEqual(Set([FeedbackTier.hit, .almost, .retry]).count, 3)
    }

    func test_pick_beforeFinish_carriesInstruction() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeRound(id: "i1"), makeRound(id: "i2")])
        await sut.start(request: .init(childId: "child-1", preferredTier: nil))
        let r0 = sut.rounds[0]
        await sut.pick(request: .init(pictureId: wrongId(r0), attemptInRound: 1))
        XCTAssertEqual(spy.lastPick?.instruction, r0.item.instruction)
    }

    // MARK: Progress / finish

    func test_pick_advancesThroughRounds() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeRound(id: "i1"), makeRound(id: "i2")])
        await sut.start(request: .init(childId: "child-1", preferredTier: nil))
        await sut.pick(request: .init(pictureId: correctId(sut.rounds[0]), attemptInRound: 1))
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(spy.lastPick?.isFinished, false)
        XCTAssertNotNil(spy.lastPick?.nextRound)
        XCTAssertEqual(spy.lastPick?.nextRoundIndex, 1)
    }

    func test_pick_lastRound_marksFinished() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeRound(id: "i1"), makeRound(id: "i2")])
        await sut.start(request: .init(childId: "child-1", preferredTier: nil))
        await sut.pick(request: .init(pictureId: correctId(sut.rounds[0]), attemptInRound: 1))
        await sut.pick(request: .init(pictureId: correctId(sut.rounds[1]), attemptInRound: 1))
        XCTAssertEqual(spy.lastPick?.isFinished, true)
        XCTAssertNil(spy.lastPick?.nextRound)
        XCTAssertEqual(spy.lastPick?.correctCount, 2)
        XCTAssertEqual(sut.accuracyFraction, 1.0, accuracy: 0.0001)
    }

    func test_pick_afterFinish_isIgnored() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeRound(id: "i1")])
        await sut.start(request: .init(childId: "child-1", preferredTier: nil))
        await sut.pick(request: .init(pictureId: correctId(sut.rounds[0]), attemptInRound: 1))
        let afterFinish = spy.pickCount
        await sut.pick(request: .init(pictureId: "anything", attemptInRound: 1))
        XCTAssertEqual(spy.pickCount, afterFinish)
    }

    // MARK: Adaptive (SM-2)

    func test_finish_recordsSessionResult_perfect() async {
        let (sut, _, _, _, planner) = makeSUT(
            rounds: [makeRound(id: "i1"), makeRound(id: "i2")], soundTarget: "понимание речи"
        )
        await sut.start(request: .init(childId: "child-1", preferredTier: nil))
        await sut.pick(request: .init(pictureId: correctId(sut.rounds[0]), attemptInRound: 1))
        await sut.pick(request: .init(pictureId: correctId(sut.rounds[1]), attemptInRound: 1))
        XCTAssertEqual(planner.recordCount, 1)
        XCTAssertEqual(planner.lastSound, "понимание речи")
        XCTAssertEqual(planner.lastQuality, .perfect)
    }

    func test_finish_lowAccuracy_recordsBlackout() async {
        let (sut, _, _, _, planner) = makeSUT(rounds: [makeRound(id: "i1"), makeRound(id: "i2")])
        await sut.start(request: .init(childId: "child-1", preferredTier: nil))
        // r1: 2 промаха → retry advance (0 правильных).
        await sut.pick(request: .init(pictureId: wrongId(sut.rounds[0]), attemptInRound: 1))
        await sut.pick(request: .init(pictureId: wrongId(sut.rounds[0]), attemptInRound: 2))
        // r2: 2 промаха → retry advance (0 правильных).
        await sut.pick(request: .init(pictureId: wrongId(sut.rounds[1]), attemptInRound: 1))
        await sut.pick(request: .init(pictureId: wrongId(sut.rounds[1]), attemptInRound: 2))
        XCTAssertEqual(planner.recordCount, 1)
        XCTAssertEqual(planner.lastQuality, .blackout, "0% → blackout")
    }

    // MARK: Level transition (≥80%)

    func test_recommendedNextTier_atFullAccuracy_levelsUp() async {
        let (sut, _, _, _, _) = makeSUT(
            rounds: [makeRound(id: "i1")], childAge: 8, leadTier: .simple
        )
        await sut.start(request: .init(childId: "child-1", preferredTier: nil))
        await sut.pick(request: .init(pictureId: correctId(sut.rounds[0]), attemptInRound: 1))
        XCTAssertEqual(sut.recommendedNextTier, .doubleInstruction, "100% → ступень выше")
    }

    func test_recommendedNextTier_lowAccuracy_staysOnLead() async {
        let (sut, _, _, _, _) = makeSUT(
            rounds: [makeRound(id: "i1"), makeRound(id: "i2")], childAge: 8, leadTier: .doubleInstruction
        )
        await sut.start(request: .init(childId: "child-1", preferredTier: nil))
        // 1 верно из 2 = 50% < 80% → остаёмся.
        await sut.pick(request: .init(pictureId: correctId(sut.rounds[0]), attemptInRound: 1))
        await sut.pick(request: .init(pictureId: wrongId(sut.rounds[1]), attemptInRound: 1))
        await sut.pick(request: .init(pictureId: wrongId(sut.rounds[1]), attemptInRound: 2))
        XCTAssertEqual(sut.recommendedNextTier, .doubleInstruction)
    }

    func test_recommendedNextTier_cappedByAge() async {
        // 5-летка на максимальном для возраста уровне — нельзя выше.
        let cap = ComprehensionDetectiveWorker.ageAllowedTier(age: 5)
        let (sut, _, _, _, _) = makeSUT(
            rounds: [makeRound(id: "i1")], childAge: 5, leadTier: cap
        )
        await sut.start(request: .init(childId: "child-1", preferredTier: nil))
        await sut.pick(request: .init(pictureId: correctId(sut.rounds[0]), attemptInRound: 1))
        XCTAssertLessThanOrEqual(sut.recommendedNextTier.rawValue, cap.rawValue)
    }
}
