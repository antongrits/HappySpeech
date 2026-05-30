@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubDetectiveWorker: SoundDetectiveWorkerProtocol {
    var response: SoundDetectiveModels.Start.Response
    private(set) var buildCallCount = 0
    private(set) var lastPreferredLevel: SoundDetectiveLevel?

    init(response: SoundDetectiveModels.Start.Response) {
        self.response = response
    }

    func buildSession(
        childId: String,
        preferredLevel: SoundDetectiveLevel?
    ) async -> SoundDetectiveModels.Start.Response {
        buildCallCount += 1
        lastPreferredLevel = preferredLevel
        return response
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyDetectivePresenter: SoundDetectivePresentationLogic, @unchecked Sendable {
    var startCount = 0
    var answerCount = 0
    var lastAnswer: SoundDetectiveModels.Answer.Response?

    func presentStart(response: SoundDetectiveModels.Start.Response) async {
        startCount += 1
    }
    func presentAnswer(response: SoundDetectiveModels.Answer.Response) async {
        answerCount += 1
        lastAnswer = response
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

// MARK: - Helpers

@MainActor
private func makeItem(
    id: String = "i",
    word: String = "сок",
    sound: String = "С",
    position: SoundZone = .start,
    sounds: [String] = ["с", "о", "к"],
    minLevel: SoundDetectiveLevel = .binary
) -> SoundDetectiveItem {
    .init(
        id: id, word: word, imageAsset: "word_sok",
        targetSound: sound, soundFamily: "свистящие",
        position: position, sounds: sounds, difficulty: 1, minLevel: minLevel
    )
}

@MainActor
private func makeRounds(
    level: SoundDetectiveLevel = .ternary
) -> [SoundDetectiveRound] {
    [
        .init(id: "r1", item: makeItem(id: "i1", position: .start), level: level),
        .init(id: "r2", item: makeItem(id: "i2", word: "нос", position: .end,
                                       sounds: ["н", "о", "с"]), level: level)
    ]
}

@MainActor
private func makeResponse(
    rounds: [SoundDetectiveRound],
    target: String = "С",
    level: SoundDetectiveLevel = .ternary
) -> SoundDetectiveModels.Start.Response {
    .init(rounds: rounds, targetSound: target, level: level)
}

// MARK: - Interactor Tests

@MainActor
final class SoundDetectiveInteractorTests: XCTestCase {

    private func makeSUT(
        rounds: [SoundDetectiveRound],
        level: SoundDetectiveLevel = .ternary
    ) -> (SoundDetectiveInteractor, SpyDetectivePresenter, StubDetectiveWorker, SpyHapticService, SpyDetectivePlanner) {
        let worker = StubDetectiveWorker(response: makeResponse(rounds: rounds, level: level))
        let haptic = SpyHapticService()
        let planner = SpyDetectivePlanner()
        let sut = SoundDetectiveInteractor(
            childId: "child-1", worker: worker,
            hapticService: haptic, adaptivePlanner: planner
        )
        let spy = SpyDetectivePresenter()
        sut.presenter = spy
        return (sut, spy, worker, haptic, planner)
    }

    // MARK: Start

    func test_start_buildsSessionAndPresents() async {
        let (sut, spy, worker, _, _) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1", preferredLevel: nil))
        XCTAssertEqual(worker.buildCallCount, 1)
        XCTAssertEqual(spy.startCount, 1)
        XCTAssertEqual(sut.rounds.count, 2)
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
        XCTAssertEqual(sut.attemptsInRound, 0)
    }

    func test_start_resetsProgress() async {
        let (sut, _, _, _, _) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1", preferredLevel: nil))
        await sut.answer(request: .init(chosenZone: .start, attemptInRound: 1))
        await sut.start(request: .init(childId: "child-1", preferredLevel: nil))
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
    }

    func test_start_passesPreferredLevelToWorker() async {
        let (sut, _, worker, _, _) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1", preferredLevel: .binary))
        XCTAssertEqual(worker.lastPreferredLevel, .binary)
    }

    // MARK: Zone evaluation («светофор»)

    func test_answer_correctZone_isHit_andIncrements() async {
        let (sut, spy, _, haptic, _) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1", preferredLevel: nil))
        // r1 — позиция .start; правильная зона = .start.
        await sut.answer(request: .init(chosenZone: .start, attemptInRound: 1))
        XCTAssertEqual(sut.correctCount, 1)
        XCTAssertEqual(spy.lastAnswer?.feedback, .hit)
        XCTAssertEqual(spy.lastAnswer?.correctZone, .start)
        XCTAssertEqual(haptic.notificationCount, 1)
        XCTAssertTrue(spy.lastAnswer?.advancedToNextRound ?? false)
    }

    func test_answer_firstMiss_isAlmost_doesNotAdvance() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1", preferredLevel: nil))
        // r1 правильная зона .start; выбираем .end → промах.
        await sut.answer(request: .init(chosenZone: .end, attemptInRound: 1))
        XCTAssertEqual(spy.lastAnswer?.feedback, .almost)
        XCTAssertEqual(sut.correctCount, 0)
        XCTAssertEqual(sut.currentIndex, 0, "Первый промах не продвигает раунд")
        XCTAssertFalse(spy.lastAnswer?.advancedToNextRound ?? true)
        XCTAssertFalse(spy.lastAnswer?.showHint ?? true)
        XCTAssertTrue(spy.lastAnswer?.replayWithEmphasis ?? false)
    }

    func test_answer_secondMiss_isRetry_showsHint_andAdvances() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1", preferredLevel: nil))
        await sut.answer(request: .init(chosenZone: .end, attemptInRound: 1))
        await sut.answer(request: .init(chosenZone: .middle, attemptInRound: 2))
        XCTAssertEqual(spy.lastAnswer?.feedback, .retry)
        XCTAssertTrue(spy.lastAnswer?.showHint ?? false, "После 2 промахов — подсказка")
        XCTAssertTrue(spy.lastAnswer?.advancedToNextRound ?? false, "Errorless: мягко идём дальше")
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(sut.attemptsInRound, 0, "Счётчик попыток сброшен на новом раунде")
    }

    func test_answer_neverProducesWrongTier() async {
        // Методика: только hit/almost/retry — никакого «неправильно».
        let (sut, spy, _, _, _) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1", preferredLevel: nil))
        await sut.answer(request: .init(chosenZone: .middle, attemptInRound: 1))
        let tier1 = spy.lastAnswer?.feedback
        await sut.answer(request: .init(chosenZone: .end, attemptInRound: 2))
        let tier2 = spy.lastAnswer?.feedback
        XCTAssertTrue([.almost].contains(tier1))
        XCTAssertTrue([.retry].contains(tier2))
        // FeedbackTier не содержит .wrong by design.
        XCTAssertEqual(Set([FeedbackTier.hit, .almost, .retry]).count, 3)
    }

    func test_answer_hit_providesHighlightSoundIndex() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1", preferredLevel: nil))
        // word "сок", target "С" → индекс 0.
        await sut.answer(request: .init(chosenZone: .start, attemptInRound: 1))
        XCTAssertEqual(spy.lastAnswer?.highlightSoundIndex, 0)
    }

    // MARK: Progress / finish

    func test_answer_advancesThroughRounds() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1", preferredLevel: nil))
        await sut.answer(request: .init(chosenZone: .start, attemptInRound: 1))
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(spy.lastAnswer?.isFinished, false)
        XCTAssertNotNil(spy.lastAnswer?.nextRound)
        XCTAssertEqual(spy.lastAnswer?.nextRoundIndex, 1)
    }

    func test_answer_lastRound_marksFinished() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1", preferredLevel: nil))
        await sut.answer(request: .init(chosenZone: .start, attemptInRound: 1)) // r1 hit
        await sut.answer(request: .init(chosenZone: .end, attemptInRound: 1))   // r2 hit (.end)
        XCTAssertEqual(spy.lastAnswer?.isFinished, true)
        XCTAssertNil(spy.lastAnswer?.nextRound)
        XCTAssertEqual(spy.lastAnswer?.correctCount, 2)
        XCTAssertEqual(sut.accuracyFraction, 1.0, accuracy: 0.0001)
    }

    func test_answer_afterFinish_isIgnored() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1", preferredLevel: nil))
        await sut.answer(request: .init(chosenZone: .start, attemptInRound: 1))
        await sut.answer(request: .init(chosenZone: .end, attemptInRound: 1))
        let afterFinish = spy.answerCount
        await sut.answer(request: .init(chosenZone: .start, attemptInRound: 1))
        XCTAssertEqual(spy.answerCount, afterFinish)
    }

    // MARK: Adaptive

    func test_finish_recordsSessionResult() async {
        let (sut, _, _, _, planner) = makeSUT(rounds: makeRounds(), level: .ternary)
        await sut.start(request: .init(childId: "child-1", preferredLevel: nil))
        await sut.answer(request: .init(chosenZone: .start, attemptInRound: 1))
        await sut.answer(request: .init(chosenZone: .end, attemptInRound: 1))
        XCTAssertEqual(planner.recordCount, 1)
        XCTAssertEqual(planner.lastSound, "С")
        // 2/2 верно → perfect.
        XCTAssertEqual(planner.lastQuality, .perfect)
    }

    func test_finish_lowAccuracy_recordsLowerQuality() async {
        let (sut, _, _, _, planner) = makeSUT(rounds: makeRounds(), level: .ternary)
        await sut.start(request: .init(childId: "child-1", preferredLevel: nil))
        // r1: 2 промаха → retry advance (0 правильных).
        await sut.answer(request: .init(chosenZone: .end, attemptInRound: 1))
        await sut.answer(request: .init(chosenZone: .middle, attemptInRound: 2))
        // r2: 2 промаха → retry advance (0 правильных).
        await sut.answer(request: .init(chosenZone: .start, attemptInRound: 1))
        await sut.answer(request: .init(chosenZone: .middle, attemptInRound: 2))
        XCTAssertEqual(planner.recordCount, 1)
        XCTAssertEqual(planner.lastQuality, .blackout, "0% → blackout")
    }
}

// MARK: - Worker Level Resolution Tests

@MainActor
final class SoundDetectiveWorkerLevelTests: XCTestCase {

    func test_ageGate_age5_isBinary() {
        XCTAssertEqual(SoundDetectiveWorker.ageAllowedLevel(age: 5), .binary)
    }

    func test_ageGate_age6_isTernary() {
        XCTAssertEqual(SoundDetectiveWorker.ageAllowedLevel(age: 6), .ternary)
    }

    func test_ageGate_age7_isWithAbsent() {
        XCTAssertEqual(SoundDetectiveWorker.ageAllowedLevel(age: 7), .withAbsent)
    }

    func test_ageGate_age8_isWithAbsent() {
        XCTAssertEqual(SoundDetectiveWorker.ageAllowedLevel(age: 8), .withAbsent)
    }

    func test_resolveLevel_capsPreferredAtAgeGate() {
        // 5-летке нельзя withAbsent, даже если просят.
        let level = SoundDetectiveWorker.resolveLevel(preferredLevel: .withAbsent, age: 5)
        XCTAssertEqual(level, .binary)
    }

    func test_resolveLevel_allowsLowerThanGate() {
        // 8-летка может играть на binary, если так задано.
        let level = SoundDetectiveWorker.resolveLevel(preferredLevel: .binary, age: 8)
        XCTAssertEqual(level, .binary)
    }

    func test_resolveLevel_nilUsesAgeGate() {
        XCTAssertEqual(SoundDetectiveWorker.resolveLevel(preferredLevel: nil, age: 6), .ternary)
    }

    // MARK: Session building

    func test_makeRounds_retroStart_beginsWithBinaryRounds() {
        // На ternary первые 2 раунда — binary (ретро-старт, F1-015).
        let rounds = SoundDetectiveWorker.makeRounds(level: .ternary, targetSounds: ["С"])
        XCTAssertGreaterThanOrEqual(rounds.count, 3)
        XCTAssertEqual(rounds[0].level, .binary)
        XCTAssertEqual(rounds[1].level, .binary)
        XCTAssertTrue(rounds.contains { $0.level == .ternary })
    }

    func test_makeRounds_binaryLevel_noRetroPrefix() {
        let rounds = SoundDetectiveWorker.makeRounds(level: .binary, targetSounds: ["С"])
        XCTAssertTrue(rounds.allSatisfy { $0.level == .binary })
    }

    func test_makeRounds_avoidsConsecutiveSamePosition() {
        // Антифатиговое правило: соседние раунды не повторяют позицию (где возможно).
        let rounds = SoundDetectiveWorker.makeRounds(level: .ternary, targetSounds: [])
        var consecutiveRepeats = 0
        for index in 1..<rounds.count where rounds[index].item.position == rounds[index - 1].item.position {
            consecutiveRepeats += 1
        }
        // Допускаем редкие повторы при исчерпании пула, но их должно быть мало.
        XCTAssertLessThanOrEqual(consecutiveRepeats, 2)
    }

    func test_makeRounds_respectsRoundsPerSession() {
        let rounds = SoundDetectiveWorker.makeRounds(level: .ternary, targetSounds: ["С"])
        XCTAssertEqual(rounds.count, SoundDetectiveCorpus.roundsPerSession)
    }
}

// MARK: - Corpus Tests

final class SoundDetectiveCorpusTests: XCTestCase {

    func test_corpus_isNotEmpty() {
        XCTAssertFalse(SoundDetectiveCorpus.allItems.isEmpty)
    }

    func test_itemIds_areUnique() {
        let ids = SoundDetectiveCorpus.allItems.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_soundsMatchNonEmpty() {
        for item in SoundDetectiveCorpus.allItems {
            XCTAssertFalse(item.sounds.isEmpty, "Пустая звуковая разметка: \(item.id)")
            XCTAssertFalse(item.word.isEmpty)
            XCTAssertFalse(item.imageAsset.isEmpty)
        }
    }

    func test_binaryLevel_onlyStartAndEnd() {
        let items = SoundDetectiveCorpus.items(for: .binary)
        let positions = Set(items.map(\.position))
        XCTAssertTrue(positions.isSubset(of: [.start, .end]),
                      "На binary не должно быть middle/absent")
        XCTAssertFalse(items.isEmpty)
    }

    func test_ternaryLevel_noAbsent() {
        let items = SoundDetectiveCorpus.items(for: .ternary)
        XCTAssertFalse(items.contains { $0.position == .absent })
        XCTAssertTrue(items.contains { $0.position == .middle })
    }

    func test_withAbsentLevel_hasAbsentItems() {
        let items = SoundDetectiveCorpus.items(for: .withAbsent)
        XCTAssertTrue(items.contains { $0.position == .absent },
                      "withAbsent должен содержать слова без целевого звука")
    }

    func test_absentItems_haveNoTargetSoundInSounds() {
        let absent = SoundDetectiveCorpus.allItems.filter { $0.position == .absent }
        XCTAssertFalse(absent.isEmpty)
        for item in absent {
            let target = item.targetSound.lowercased()
            XCTAssertFalse(item.sounds.contains { $0.lowercased() == target },
                           "У absent-слова \(item.word) не должно быть звука \(item.targetSound)")
        }
    }

    func test_items_prioritisesTargetSound() {
        let items = SoundDetectiveCorpus.items(for: .ternary, targetSounds: ["Р"])
        XCTAssertEqual(items.first?.targetSound, "Р")
    }

    func test_coversMainSoundGroups() {
        let sounds = Set(SoundDetectiveCorpus.allItems.map(\.targetSound))
        for required in ["С", "Ш", "Р", "Л", "З"] {
            XCTAssertTrue(sounds.contains(required), "Нет слов для звука \(required)")
        }
    }
}
