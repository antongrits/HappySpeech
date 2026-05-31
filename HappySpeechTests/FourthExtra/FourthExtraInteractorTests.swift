@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubFourthExtraWorker: FourthExtraWorkerProtocol {
    var response: FourthExtraModels.Start.Response
    private(set) var buildCallCount = 0
    private(set) var lastPreferredVariant: ExtraVariant?

    init(response: FourthExtraModels.Start.Response) {
        self.response = response
    }

    func buildSession(
        childId: String,
        preferredVariant: ExtraVariant?
    ) async -> FourthExtraModels.Start.Response {
        buildCallCount += 1
        lastPreferredVariant = preferredVariant
        return response
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyFourthExtraPresenter: FourthExtraPresentationLogic, @unchecked Sendable {
    var startCount = 0
    var answerCount = 0
    var lastAnswer: FourthExtraModels.Answer.Response?

    func presentStart(response: FourthExtraModels.Start.Response) async {
        startCount += 1
    }
    func presentAnswer(response: FourthExtraModels.Answer.Response) async {
        answerCount += 1
        lastAnswer = response
    }
}

// MARK: - Spy AdaptivePlanner

private final class SpyFourthExtraPlanner: AdaptivePlannerService, @unchecked Sendable {
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
private func makeSemanticRound(
    id: String = "r-sem",
    extraIndex: Int = 3,
    category: String = "фрукты"
) -> FourthExtraRound {
    let words = ["яблоко", "груша", "банан", "стул"]
    let assets = ["word_apple", "word_grusha", "word_banan", "word_stul"]
    let cards = (0..<4).map { idx in
        ExtraCard(
            id: "\(id)-\(idx)",
            word: words[idx],
            imageAsset: assets[idx],
            isExtra: idx == extraIndex,
            extraReason: idx == extraIndex ? "это мебель" : nil
        )
    }
    return FourthExtraRound(
        id: id, variant: .semantic, rule: .category,
        categoryLabel: category, targetSound: nil,
        cards: cards, difficulty: 1, minAge: 5
    )
}

@MainActor
private func makePhoneticRound(
    id: String = "r-phon",
    extraIndex: Int = 3,
    sound: String = "Ш"
) -> FourthExtraRound {
    let words = ["шапка", "шуба", "машина", "рак"]
    let assets = ["word_hat", "word_shuba", "word_car", "word_rak"]
    let cards = (0..<4).map { idx in
        ExtraCard(
            id: "\(id)-\(idx)",
            word: words[idx],
            imageAsset: assets[idx],
            isExtra: idx == extraIndex,
            extraReason: idx == extraIndex ? "в слове нет звука Ш" : nil
        )
    }
    return FourthExtraRound(
        id: id, variant: .phonetic, rule: .sound,
        categoryLabel: nil, targetSound: sound,
        cards: cards, difficulty: 2, minAge: 6
    )
}

@MainActor
private func makeResponse(
    rounds: [FourthExtraRound],
    soundTarget: String = "лексика",
    childAge: Int = 6
) -> FourthExtraModels.Start.Response {
    .init(rounds: rounds, soundTarget: soundTarget, childAge: childAge)
}

// MARK: - Interactor Tests

@MainActor
final class FourthExtraInteractorTests: XCTestCase {

    private func makeSUT(
        rounds: [FourthExtraRound],
        soundTarget: String = "лексика",
        childAge: Int = 6
    ) -> (FourthExtraInteractor, SpyFourthExtraPresenter, StubFourthExtraWorker, SpyHapticService, SpyFourthExtraPlanner) {
        let worker = StubFourthExtraWorker(
            response: makeResponse(rounds: rounds, soundTarget: soundTarget, childAge: childAge)
        )
        let haptic = SpyHapticService()
        let planner = SpyFourthExtraPlanner()
        let sut = FourthExtraInteractor(
            childId: "child-1", worker: worker,
            hapticService: haptic, adaptivePlanner: planner
        )
        let spy = SpyFourthExtraPresenter()
        sut.presenter = spy
        return (sut, spy, worker, haptic, planner)
    }

    // MARK: Start

    func test_start_buildsSessionAndPresents() async {
        let (sut, spy, worker, _, _) = makeSUT(rounds: [makeSemanticRound(), makePhoneticRound()])
        await sut.start(request: .init(childId: "child-1", preferredVariant: nil))
        XCTAssertEqual(worker.buildCallCount, 1)
        XCTAssertEqual(spy.startCount, 1)
        XCTAssertEqual(sut.rounds.count, 2)
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
        XCTAssertEqual(sut.attemptsInRound, 0)
    }

    func test_start_resetsProgress() async {
        let (sut, _, _, _, _) = makeSUT(rounds: [makeSemanticRound(), makePhoneticRound()])
        await sut.start(request: .init(childId: "child-1", preferredVariant: nil))
        await sut.answer(request: .init(chosenCardId: "r-sem-3", attemptInRound: 1))
        await sut.start(request: .init(childId: "child-1", preferredVariant: nil))
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
    }

    func test_start_passesPreferredVariantToWorker() async {
        let (sut, _, worker, _, _) = makeSUT(rounds: [makeSemanticRound()])
        await sut.start(request: .init(childId: "child-1", preferredVariant: .phonetic))
        XCTAssertEqual(worker.lastPreferredVariant, .phonetic)
    }

    // MARK: Extra-card evaluation («светофор»)

    func test_answer_correctExtra_isHit_andIncrements() async {
        let (sut, spy, _, haptic, _) = makeSUT(rounds: [makeSemanticRound(extraIndex: 3)])
        await sut.start(request: .init(childId: "child-1", preferredVariant: nil))
        // Лишний — карточка с индексом 3 → id "r-sem-3".
        await sut.answer(request: .init(chosenCardId: "r-sem-3", attemptInRound: 1))
        XCTAssertEqual(sut.correctCount, 1)
        XCTAssertEqual(spy.lastAnswer?.feedback, .hit)
        XCTAssertEqual(spy.lastAnswer?.extraCardId, "r-sem-3")
        XCTAssertEqual(haptic.notificationCount, 1)
        XCTAssertTrue(spy.lastAnswer?.advancedToNextRound ?? false)
    }

    func test_answer_hit_providesGroupingLabelAndReason() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeSemanticRound(extraIndex: 3, category: "фрукты")])
        await sut.start(request: .init(childId: "child-1", preferredVariant: nil))
        await sut.answer(request: .init(chosenCardId: "r-sem-3", attemptInRound: 1))
        XCTAssertEqual(spy.lastAnswer?.groupingLabel, "фрукты")
        XCTAssertEqual(spy.lastAnswer?.extraReason, "это мебель")
    }

    func test_answer_firstMiss_isAlmost_doesNotAdvance() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeSemanticRound(extraIndex: 3)])
        await sut.start(request: .init(childId: "child-1", preferredVariant: nil))
        // Выбираем «свою» (idx 0) → промах.
        await sut.answer(request: .init(chosenCardId: "r-sem-0", attemptInRound: 1))
        XCTAssertEqual(spy.lastAnswer?.feedback, .almost)
        XCTAssertEqual(sut.correctCount, 0)
        XCTAssertEqual(sut.currentIndex, 0, "Первый промах не продвигает раунд")
        XCTAssertFalse(spy.lastAnswer?.advancedToNextRound ?? true)
        XCTAssertFalse(spy.lastAnswer?.showHint ?? true)
        XCTAssertTrue(spy.lastAnswer?.hintCardIds.isEmpty ?? false)
    }

    func test_answer_secondMiss_isRetry_showsHint_andAdvances() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeSemanticRound(extraIndex: 3), makePhoneticRound()])
        await sut.start(request: .init(childId: "child-1", preferredVariant: nil))
        await sut.answer(request: .init(chosenCardId: "r-sem-0", attemptInRound: 1))
        await sut.answer(request: .init(chosenCardId: "r-sem-1", attemptInRound: 2))
        XCTAssertEqual(spy.lastAnswer?.feedback, .retry)
        XCTAssertTrue(spy.lastAnswer?.showHint ?? false, "После 2 промахов — подсказка")
        XCTAssertTrue(spy.lastAnswer?.advancedToNextRound ?? false, "Errorless: мягко идём дальше")
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(sut.attemptsInRound, 0, "Счётчик попыток сброшен на новом раунде")
    }

    func test_answer_hint_highlightsThreeNonExtraCards() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeSemanticRound(extraIndex: 3)])
        await sut.start(request: .init(childId: "child-1", preferredVariant: nil))
        await sut.answer(request: .init(chosenCardId: "r-sem-0", attemptInRound: 1))
        await sut.answer(request: .init(chosenCardId: "r-sem-1", attemptInRound: 2))
        // Подсказка — три «не-лишних» (idx 0,1,2), не содержит лишнюю (idx 3).
        XCTAssertEqual(Set(spy.lastAnswer?.hintCardIds ?? []), ["r-sem-0", "r-sem-1", "r-sem-2"])
        XCTAssertFalse(spy.lastAnswer?.hintCardIds.contains("r-sem-3") ?? true)
    }

    func test_answer_neverProducesWrongTier() async {
        // Методика: только hit/almost/retry — никакого «неправильно».
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeSemanticRound(extraIndex: 3)])
        await sut.start(request: .init(childId: "child-1", preferredVariant: nil))
        await sut.answer(request: .init(chosenCardId: "r-sem-0", attemptInRound: 1))
        let tier1 = spy.lastAnswer?.feedback
        await sut.answer(request: .init(chosenCardId: "r-sem-1", attemptInRound: 2))
        let tier2 = spy.lastAnswer?.feedback
        XCTAssertEqual(tier1, .almost)
        XCTAssertEqual(tier2, .retry)
        XCTAssertEqual(Set([FeedbackTier.hit, .almost, .retry]).count, 3)
    }

    // MARK: Verbalisation gate (7–8, semantic)

    func test_answer_hit_semantic_age7_asksWhy() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeSemanticRound(extraIndex: 3)], childAge: 7)
        await sut.start(request: .init(childId: "child-1", preferredVariant: nil))
        await sut.answer(request: .init(chosenCardId: "r-sem-3", attemptInRound: 1))
        XCTAssertTrue(spy.lastAnswer?.askWhy ?? false, "7–8 лет, semantic → спрашиваем «почему лишний»")
    }

    func test_answer_hit_semantic_age5_doesNotAskWhy() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeSemanticRound(extraIndex: 3)], childAge: 5)
        await sut.start(request: .init(childId: "child-1", preferredVariant: nil))
        await sut.answer(request: .init(chosenCardId: "r-sem-3", attemptInRound: 1))
        XCTAssertFalse(spy.lastAnswer?.askWhy ?? true)
    }

    func test_answer_hit_phonetic_age7_doesNotAskWhy() async {
        let (sut, spy, _, _, _) = makeSUT(
            rounds: [makePhoneticRound(extraIndex: 3)], soundTarget: "Ш", childAge: 7
        )
        await sut.start(request: .init(childId: "child-1", preferredVariant: nil))
        await sut.answer(request: .init(chosenCardId: "r-phon-3", attemptInRound: 1))
        XCTAssertFalse(spy.lastAnswer?.askWhy ?? true, "Вербализация только для semantic")
    }

    func test_answer_hit_phonetic_groupingMentionsSound() async {
        let (sut, spy, _, _, _) = makeSUT(
            rounds: [makePhoneticRound(extraIndex: 3, sound: "Ш")], soundTarget: "Ш"
        )
        await sut.start(request: .init(childId: "child-1", preferredVariant: nil))
        await sut.answer(request: .init(chosenCardId: "r-phon-3", attemptInRound: 1))
        XCTAssertNotNil(spy.lastAnswer?.groupingLabel)
        XCTAssertTrue(spy.lastAnswer?.groupingLabel?.contains("Ш") ?? false)
    }

    // MARK: Progress / finish

    func test_answer_advancesThroughRounds() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeSemanticRound(extraIndex: 3), makePhoneticRound()])
        await sut.start(request: .init(childId: "child-1", preferredVariant: nil))
        await sut.answer(request: .init(chosenCardId: "r-sem-3", attemptInRound: 1))
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(spy.lastAnswer?.isFinished, false)
        XCTAssertNotNil(spy.lastAnswer?.nextRound)
        XCTAssertEqual(spy.lastAnswer?.nextRoundIndex, 1)
    }

    func test_answer_lastRound_marksFinished() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeSemanticRound(extraIndex: 3), makePhoneticRound(extraIndex: 3)])
        await sut.start(request: .init(childId: "child-1", preferredVariant: nil))
        await sut.answer(request: .init(chosenCardId: "r-sem-3", attemptInRound: 1))
        await sut.answer(request: .init(chosenCardId: "r-phon-3", attemptInRound: 1))
        XCTAssertEqual(spy.lastAnswer?.isFinished, true)
        XCTAssertNil(spy.lastAnswer?.nextRound)
        XCTAssertEqual(spy.lastAnswer?.correctCount, 2)
        XCTAssertEqual(sut.accuracyFraction, 1.0, accuracy: 0.0001)
    }

    func test_answer_afterFinish_isIgnored() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeSemanticRound(extraIndex: 3)])
        await sut.start(request: .init(childId: "child-1", preferredVariant: nil))
        await sut.answer(request: .init(chosenCardId: "r-sem-3", attemptInRound: 1))
        let afterFinish = spy.answerCount
        await sut.answer(request: .init(chosenCardId: "r-sem-3", attemptInRound: 1))
        XCTAssertEqual(spy.answerCount, afterFinish)
    }

    // MARK: Adaptive

    func test_finish_recordsSessionResult_perfect() async {
        let (sut, _, _, _, planner) = makeSUT(
            rounds: [makeSemanticRound(extraIndex: 3), makePhoneticRound(extraIndex: 3)],
            soundTarget: "лексика"
        )
        await sut.start(request: .init(childId: "child-1", preferredVariant: nil))
        await sut.answer(request: .init(chosenCardId: "r-sem-3", attemptInRound: 1))
        await sut.answer(request: .init(chosenCardId: "r-phon-3", attemptInRound: 1))
        XCTAssertEqual(planner.recordCount, 1)
        XCTAssertEqual(planner.lastSound, "лексика")
        XCTAssertEqual(planner.lastQuality, .perfect)
    }

    func test_finish_lowAccuracy_recordsBlackout() async {
        let (sut, _, _, _, planner) = makeSUT(
            rounds: [makeSemanticRound(extraIndex: 3), makePhoneticRound(extraIndex: 3)]
        )
        await sut.start(request: .init(childId: "child-1", preferredVariant: nil))
        // r1: 2 промаха → retry advance (0 правильных).
        await sut.answer(request: .init(chosenCardId: "r-sem-0", attemptInRound: 1))
        await sut.answer(request: .init(chosenCardId: "r-sem-1", attemptInRound: 2))
        // r2: 2 промаха → retry advance (0 правильных).
        await sut.answer(request: .init(chosenCardId: "r-phon-0", attemptInRound: 1))
        await sut.answer(request: .init(chosenCardId: "r-phon-1", attemptInRound: 2))
        XCTAssertEqual(planner.recordCount, 1)
        XCTAssertEqual(planner.lastQuality, .blackout, "0% → blackout")
    }
}
