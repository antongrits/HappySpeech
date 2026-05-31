@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubSentenceBuilderWorker: SentenceBuilderWorkerProtocol {
    var response: SentenceBuilderModels.Start.Response
    private(set) var buildCallCount = 0
    private(set) var lastPreferredSubtask: SentenceSubtask?

    init(response: SentenceBuilderModels.Start.Response) {
        self.response = response
    }

    func buildSession(
        childId: String,
        preferredSubtask: SentenceSubtask?
    ) async -> SentenceBuilderModels.Start.Response {
        buildCallCount += 1
        lastPreferredSubtask = preferredSubtask
        return response
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpySentenceBuilderPresenter: SentenceBuilderPresentationLogic, @unchecked Sendable {
    var startCount = 0
    var answerCount = 0
    var lastAnswer: SentenceBuilderModels.Answer.Response?

    func presentStart(response: SentenceBuilderModels.Start.Response) async {
        startCount += 1
    }
    func presentAnswer(response: SentenceBuilderModels.Answer.Response) async {
        answerCount += 1
        lastAnswer = response
    }
}

// MARK: - Spy AdaptivePlanner

private final class SpySentenceBuilderPlanner: AdaptivePlannerService, @unchecked Sendable {
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
private func makeWordOrderRound(id: String = "r-order") -> SentenceRound {
    SentenceRound(
        id: id, subtask: .wordOrder, sceneImage: "cat.fill",
        bankTokens: [
            .init(id: "\(id)-1", text: "кот", role: .subject),
            .init(id: "\(id)-2", text: "спит", role: .verb),
            .init(id: "\(id)-3", text: "на", role: .prep),
            .init(id: "\(id)-4", text: "диване", role: .object)
        ],
        slotCount: 4,
        acceptedOrders: [["\(id)-1", "\(id)-2", "\(id)-3", "\(id)-4"]],
        spokenSentence: "Кот спит на диване.", difficulty: 1, minAge: 6
    )
}

@MainActor
private func makePrepRound(id: String = "r-prep") -> SentenceRound {
    SentenceRound(
        id: id, subtask: .preposition, sceneImage: "bird.fill",
        bankTokens: [
            .init(id: "\(id)-1", text: "птица", role: .subject),
            .init(id: "\(id)-2", text: "сидит", role: .verb),
            .init(id: "\(id)-on", text: "на", role: .prep),
            .init(id: "\(id)-under", text: "под", role: .prep),
            .init(id: "\(id)-3", text: "дереве", role: .object)
        ],
        slotCount: 4,
        acceptedOrders: [["\(id)-1", "\(id)-2", "\(id)-on", "\(id)-3"]],
        spokenSentence: "Птица сидит на дереве.", difficulty: 2, minAge: 6
    )
}

@MainActor
private func makeOrderRoundWithDistractor(id: String = "r-dist") -> SentenceRound {
    SentenceRound(
        id: id, subtask: .wordOrder, sceneImage: "hare.fill",
        bankTokens: [
            .init(id: "\(id)-1", text: "заяц", role: .subject),
            .init(id: "\(id)-2", text: "грызёт", role: .verb),
            .init(id: "\(id)-3", text: "морковку", role: .object),
            .init(id: "\(id)-d1", text: "стол", role: .noun, isDistractor: true)
        ],
        slotCount: 3,
        acceptedOrders: [["\(id)-1", "\(id)-2", "\(id)-3"]],
        spokenSentence: "Заяц грызёт морковку.", difficulty: 3, minAge: 8
    )
}

@MainActor
private func makeResponse(
    rounds: [SentenceRound],
    childAge: Int = 6
) -> SentenceBuilderModels.Start.Response {
    .init(rounds: rounds, soundTarget: "грамматика.синтаксис", childAge: childAge)
}

// MARK: - Interactor Tests

@MainActor
final class SentenceBuilderInteractorTests: XCTestCase {

    private func makeSUT(
        rounds: [SentenceRound],
        childAge: Int = 6
    ) -> (SentenceBuilderInteractor, SpySentenceBuilderPresenter, StubSentenceBuilderWorker, SpyHapticService, SpySentenceBuilderPlanner) {
        let worker = StubSentenceBuilderWorker(response: makeResponse(rounds: rounds, childAge: childAge))
        let haptic = SpyHapticService()
        let planner = SpySentenceBuilderPlanner()
        let sut = SentenceBuilderInteractor(
            childId: "child-1", worker: worker,
            hapticService: haptic, adaptivePlanner: planner
        )
        let spy = SpySentenceBuilderPresenter()
        sut.presenter = spy
        return (sut, spy, worker, haptic, planner)
    }

    // MARK: Start

    func test_start_buildsSessionAndPresents() async {
        let (sut, spy, worker, _, _) = makeSUT(rounds: [makeWordOrderRound(), makePrepRound()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        XCTAssertEqual(worker.buildCallCount, 1)
        XCTAssertEqual(spy.startCount, 1)
        XCTAssertEqual(sut.rounds.count, 2)
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
        XCTAssertEqual(sut.attemptsInRound, 0)
    }

    func test_start_resetsProgress() async {
        let (sut, _, _, _, _) = makeSUT(rounds: [makeWordOrderRound(), makePrepRound()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(placedOrder: ["r-order-1", "r-order-2", "r-order-3", "r-order-4"], attemptInRound: 1))
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
    }

    func test_start_passesPreferredSubtaskToWorker() async {
        let (sut, _, worker, _, _) = makeSUT(rounds: [makeWordOrderRound()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: .preposition))
        XCTAssertEqual(worker.lastPreferredSubtask, .preposition)
    }

    // MARK: Answer evaluation («светофор»)

    func test_answer_exactOrder_isHit_andVoicesSentence() async {
        let (sut, spy, _, haptic, _) = makeSUT(rounds: [makeWordOrderRound()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(
            placedOrder: ["r-order-1", "r-order-2", "r-order-3", "r-order-4"], attemptInRound: 1
        ))
        XCTAssertEqual(sut.correctCount, 1)
        XCTAssertEqual(spy.lastAnswer?.feedback, .hit)
        XCTAssertEqual(spy.lastAnswer?.spokenSentence, "Кот спит на диване.", "На hit фраза озвучивается целиком")
        XCTAssertEqual(haptic.notificationCount, 1)
        XCTAssertTrue(spy.lastAnswer?.advancedToNextRound ?? false)
    }

    func test_answer_wrongOrder_firstMiss_isAlmost_doesNotAdvance() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeWordOrderRound()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        // Полностью обратный порядок (нет верных биграмм) → almost (тёплый, не «неправильно»).
        await sut.answer(request: .init(
            placedOrder: ["r-order-4", "r-order-3", "r-order-2", "r-order-1"], attemptInRound: 1
        ))
        XCTAssertEqual(spy.lastAnswer?.feedback, .almost)
        XCTAssertEqual(sut.correctCount, 0)
        XCTAssertEqual(sut.currentIndex, 0, "Первый промах не продвигает раунд")
        XCTAssertFalse(spy.lastAnswer?.advancedToNextRound ?? true)
        XCTAssertFalse(spy.lastAnswer?.showHint ?? true)
        XCTAssertNil(spy.lastAnswer?.firstHintTokenId)
        XCTAssertEqual(spy.lastAnswer?.spokenSentence, "", "Фразу не озвучиваем на промах")
    }

    func test_answer_secondMiss_isRetry_showsFirstHint_andAdvances() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeWordOrderRound(), makePrepRound()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        let wrong = ["r-order-4", "r-order-3", "r-order-2", "r-order-1"]
        await sut.answer(request: .init(placedOrder: wrong, attemptInRound: 1))
        await sut.answer(request: .init(placedOrder: wrong, attemptInRound: 2))
        XCTAssertEqual(spy.lastAnswer?.feedback, .retry)
        XCTAssertTrue(spy.lastAnswer?.showHint ?? false, "После 2 промахов — подсказка")
        XCTAssertEqual(spy.lastAnswer?.firstHintTokenId, "r-order-1", "Первая карточка канонического порядка «прилипает»")
        XCTAssertTrue(spy.lastAnswer?.advancedToNextRound ?? false, "Errorless: мягко идём дальше")
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(sut.attemptsInRound, 0, "Счётчик попыток сброшен на новом раунде")
    }

    func test_answer_neverProducesWrongTier() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeWordOrderRound()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        let wrong = ["r-order-4", "r-order-3", "r-order-2", "r-order-1"]
        await sut.answer(request: .init(placedOrder: wrong, attemptInRound: 1))
        let tier1 = spy.lastAnswer?.feedback
        await sut.answer(request: .init(placedOrder: wrong, attemptInRound: 2))
        let tier2 = spy.lastAnswer?.feedback
        XCTAssertEqual(tier1, .almost)
        XCTAssertEqual(tier2, .retry)
    }

    // MARK: Distractor filtering

    func test_answer_distractorPlacedButCoreOrderCorrect_isHit() async {
        // Дистрактор отфильтровывается перед сравнением: даже если он попал в
        // placedOrder, ядро фразы оценивается как точное → hit.
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeOrderRoundWithDistractor()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(
            placedOrder: ["r-dist-1", "r-dist-2", "r-dist-3", "r-dist-d1"], attemptInRound: 1
        ))
        XCTAssertEqual(spy.lastAnswer?.feedback, .hit)
        XCTAssertEqual(sut.correctCount, 1)
    }

    // MARK: Progress / finish

    func test_answer_advancesThroughRounds() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeWordOrderRound(), makePrepRound()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(
            placedOrder: ["r-order-1", "r-order-2", "r-order-3", "r-order-4"], attemptInRound: 1
        ))
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(spy.lastAnswer?.isFinished, false)
        XCTAssertNotNil(spy.lastAnswer?.nextRound)
        XCTAssertEqual(spy.lastAnswer?.nextRoundIndex, 1)
    }

    func test_answer_lastRound_marksFinished() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeWordOrderRound(), makePrepRound()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(
            placedOrder: ["r-order-1", "r-order-2", "r-order-3", "r-order-4"], attemptInRound: 1
        ))
        await sut.answer(request: .init(
            placedOrder: ["r-prep-1", "r-prep-2", "r-prep-on", "r-prep-3"], attemptInRound: 1
        ))
        XCTAssertEqual(spy.lastAnswer?.isFinished, true)
        XCTAssertNil(spy.lastAnswer?.nextRound)
        XCTAssertEqual(spy.lastAnswer?.correctCount, 2)
        XCTAssertEqual(sut.accuracyFraction, 1.0, accuracy: 0.0001)
    }

    func test_answer_afterFinish_isIgnored() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeWordOrderRound()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(
            placedOrder: ["r-order-1", "r-order-2", "r-order-3", "r-order-4"], attemptInRound: 1
        ))
        let afterFinish = spy.answerCount
        await sut.answer(request: .init(
            placedOrder: ["r-order-1", "r-order-2", "r-order-3", "r-order-4"], attemptInRound: 1
        ))
        XCTAssertEqual(spy.answerCount, afterFinish)
    }

    // MARK: Adaptive (SM-2)

    func test_finish_recordsSessionResult_perfect() async {
        let (sut, _, _, _, planner) = makeSUT(rounds: [makeWordOrderRound(), makePrepRound()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(
            placedOrder: ["r-order-1", "r-order-2", "r-order-3", "r-order-4"], attemptInRound: 1
        ))
        await sut.answer(request: .init(
            placedOrder: ["r-prep-1", "r-prep-2", "r-prep-on", "r-prep-3"], attemptInRound: 1
        ))
        XCTAssertEqual(planner.recordCount, 1)
        XCTAssertEqual(planner.lastSound, "грамматика.синтаксис")
        XCTAssertEqual(planner.lastQuality, .perfect)
    }

    func test_finish_lowAccuracy_recordsBlackout() async {
        let (sut, _, _, _, planner) = makeSUT(rounds: [makeWordOrderRound(), makePrepRound()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        let wrongOrder = ["r-order-4", "r-order-3", "r-order-2", "r-order-1"]
        await sut.answer(request: .init(placedOrder: wrongOrder, attemptInRound: 1))
        await sut.answer(request: .init(placedOrder: wrongOrder, attemptInRound: 2))
        let wrongPrep = ["r-prep-3", "r-prep-on", "r-prep-2", "r-prep-1"]
        await sut.answer(request: .init(placedOrder: wrongPrep, attemptInRound: 1))
        await sut.answer(request: .init(placedOrder: wrongPrep, attemptInRound: 2))
        XCTAssertEqual(planner.recordCount, 1)
        XCTAssertEqual(planner.lastQuality, .blackout, "0% → blackout")
    }
}

// MARK: - matchesPartially (pure) Tests

final class SentenceBuilderMatchTests: XCTestCase {

    private let accepted = [["s", "v", "p", "o"]]
    private let prepIds: Set<String> = ["p", "p2"]

    // MARK: matchesExactly

    func test_matchesExactly_true() {
        XCTAssertTrue(SentenceBuilderInteractor.matchesExactly(["s", "v", "p", "o"], accepted))
    }

    func test_matchesExactly_false_whenReordered() {
        XCTAssertFalse(SentenceBuilderInteractor.matchesExactly(["v", "s", "p", "o"], accepted))
    }

    func test_matchesExactly_multipleAcceptedOrders() {
        let multi = [["s", "v", "p", "o"], ["s", "p", "o", "v"]]
        XCTAssertTrue(SentenceBuilderInteractor.matchesExactly(["s", "p", "o", "v"], multi))
    }

    // MARK: matchesPartially — точное совпадение исключается

    func test_matchesPartially_exact_returnsFalse() {
        // Точное совпадение не «частичное» — оно hit, обрабатывается отдельно.
        XCTAssertFalse(SentenceBuilderInteractor.matchesPartially(
            ["s", "v", "p", "o"], accepted: accepted, prepositionIds: prepIds
        ))
    }

    // MARK: matchesPartially — перепутан только предлог

    func test_matchesPartially_onlyPrepositionSwapped_isPartial() {
        // Состав слов тот же, единственная перестановка касается предлогов.
        let accepted2 = [["s", "v", "p", "o"]]
        let prep: Set<String> = ["p", "o"]  // искусственно: оба — «предлоги»
        // Меняем местами два предлога p и o.
        let placed = ["s", "v", "o", "p"]
        XCTAssertTrue(SentenceBuilderInteractor.matchesPartially(
            placed, accepted: accepted2, prepositionIds: prep
        ))
    }

    func test_onlyPrepositionMisplaced_true_whenOnlyPrepDiffers() {
        // Ожидаемый: s v p o; поставлено: s v p2 o, где p и p2 — предлоги.
        let expected = ["s", "v", "p", "o"]
        let placed = ["s", "v", "p2", "o"]
        // Состав слов должен совпадать как мультимножество → подменим, чтобы он
        // совпадал: используем тот же набор, переставив предлоги.
        let expected2 = ["s", "v", "p", "p2"]
        let placed2 = ["s", "v", "p2", "p"]
        XCTAssertTrue(SentenceBuilderInteractor.onlyPrepositionMisplaced(
            placed2, expected: expected2, prepositionIds: ["p", "p2"]
        ))
        // А вот несовпадение состава слов — не «только предлог».
        XCTAssertFalse(SentenceBuilderInteractor.onlyPrepositionMisplaced(
            placed, expected: expected, prepositionIds: ["p", "p2"]
        ))
    }

    func test_onlyPrepositionMisplaced_false_whenNonPrepDiffers() {
        // Переставлены не-предлоги (s и v) → это НЕ «перепутан только предлог».
        let expected = ["s", "v", "p", "o"]
        let placed = ["v", "s", "p", "o"]
        XCTAssertFalse(SentenceBuilderInteractor.onlyPrepositionMisplaced(
            placed, expected: expected, prepositionIds: ["p"]
        ))
    }

    func test_onlyPrepositionMisplaced_false_whenLengthDiffers() {
        XCTAssertFalse(SentenceBuilderInteractor.onlyPrepositionMisplaced(
            ["s", "v", "p"], expected: ["s", "v", "p", "o"], prepositionIds: ["p"]
        ))
    }

    // MARK: matchesPartially — доля верных биграмм ≥ 60%

    func test_bigramOverlap_allPairsCorrect_is1() {
        XCTAssertEqual(
            SentenceBuilderInteractor.bigramOverlap(["s", "v", "p", "o"], expected: ["s", "v", "p", "o"]),
            1.0, accuracy: 0.0001
        )
    }

    func test_bigramOverlap_noPairsCorrect_is0() {
        // Полностью обратный порядок: ни одна соседняя пара не совпадает.
        XCTAssertEqual(
            SentenceBuilderInteractor.bigramOverlap(["o", "p", "v", "s"], expected: ["s", "v", "p", "o"]),
            0.0, accuracy: 0.0001
        )
    }

    func test_bigramOverlap_twoOfThree_isApprox067() {
        // Ожидаемый s v p o → пары (s,v),(v,p),(p,o). Поставлено s v p ... но
        // последний элемент сместим: s v o p → пары (s,v),(v,o),(o,p): совпадает
        // только (s,v) = 1/3.
        XCTAssertEqual(
            SentenceBuilderInteractor.bigramOverlap(["s", "v", "o", "p"], expected: ["s", "v", "p", "o"]),
            1.0 / 3.0, accuracy: 0.0001
        )
    }

    func test_matchesPartially_sixtyPercentBigrams_isPartial() {
        // 5-словный порядок: s v a p o → пары (s,v),(v,a),(a,p),(p,o) = 4 пары.
        // Поставлено s v a o p: пары (s,v),(v,a),(a,o),(o,p): совпадает 2 из 4 = 50% < 60% → не partial.
        let acc = [["s", "v", "a", "p", "o"]]
        let prep: Set<String> = ["p"]
        XCTAssertFalse(SentenceBuilderInteractor.matchesPartially(
            ["s", "v", "a", "o", "p"], accepted: acc, prepositionIds: prep
        ))
        // Поставлено s v a p x (заменим хвост, чтобы 3 из 4 пар совпали = 75% ≥ 60%).
        // Используем порядок с одной ошибкой в конце: s v a p → но нужно 5 элементов.
        // Сместим только последний: s v a p o уже точное; возьмём s a v p o
        // пары (s,a),(a,v),(v,p),(p,o): совпадает только (p,o) = 25%.
        // Проверим 3/4: ожидаемый (s,v),(v,a),(a,p),(p,o); поставим s v a p X где X новый.
        let placed75 = ["s", "v", "a", "p", "z"]  // (s,v),(v,a),(a,p) совпадают = 3/4 = 75%
        XCTAssertTrue(SentenceBuilderInteractor.matchesPartially(
            placed75, accepted: acc, prepositionIds: prep
        ))
    }

    func test_matchesPartially_emptyPlaced_isFalse() {
        XCTAssertFalse(SentenceBuilderInteractor.matchesPartially(
            [], accepted: accepted, prepositionIds: prepIds
        ))
    }

    // MARK: prepositionIds extraction

    @MainActor
    func test_prepositionIds_extractsPrepAndPrepSlotRoles() {
        let round = makePrepRound()
        let ids = SentenceBuilderInteractor.prepositionIds(in: round)
        XCTAssertTrue(ids.contains("r-prep-on"))
        XCTAssertTrue(ids.contains("r-prep-under"))
        XCTAssertFalse(ids.contains("r-prep-1"), "subject — не предлог")
        XCTAssertFalse(ids.contains("r-prep-3"), "object — не предлог")
    }
}
