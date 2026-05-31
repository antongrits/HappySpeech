@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubWhoseTailWorker: WhoseTailWorkerProtocol {
    var response: WhoseTailModels.Start.Response
    private(set) var buildCallCount = 0
    private(set) var lastPreferredSubtask: WhoseSubtask?

    init(response: WhoseTailModels.Start.Response) {
        self.response = response
    }

    func buildSession(
        childId: String,
        preferredSubtask: WhoseSubtask?
    ) async -> WhoseTailModels.Start.Response {
        buildCallCount += 1
        lastPreferredSubtask = preferredSubtask
        return response
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyWhoseTailPresenter: WhoseTailPresentationLogic, @unchecked Sendable {
    var startCount = 0
    var answerCount = 0
    var lastAnswer: WhoseTailModels.Answer.Response?

    func presentStart(response: WhoseTailModels.Start.Response) async {
        startCount += 1
    }
    func presentAnswer(response: WhoseTailModels.Answer.Response) async {
        answerCount += 1
        lastAnswer = response
    }
}

// MARK: - Spy AdaptivePlanner

private final class SpyWhoseTailPlanner: AdaptivePlannerService, @unchecked Sendable {
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
private func makePossessiveRound(
    id: String = "r-poss",
    correctIndex: Int = 0
) -> WhoseRound {
    let options = [
        WhoseOption(id: "\(id)-0", word: "лиса", imageAsset: "word_fox",
                    isCorrect: correctIndex == 0, form: "лисий хвост"),
        WhoseOption(id: "\(id)-1", word: "заяц", imageAsset: "word_hare",
                    isCorrect: correctIndex == 1, form: "заячий хвост")
    ]
    return WhoseRound(
        id: id, subtask: .possessiveTail, cueImage: "pawprint.fill",
        question: "Чей это хвост?", options: options,
        spokenForm: "Это лисий хвост.", difficulty: 1, minAge: 5
    )
}

@MainActor
private func makeRelativeRound(
    id: String = "r-rel",
    correctIndex: Int = 0
) -> WhoseRound {
    let options = [
        WhoseOption(id: "\(id)-0", word: "дерево", imageAsset: "word_derevo",
                    isCorrect: correctIndex == 0, form: "деревянный стол"),
        WhoseOption(id: "\(id)-1", word: "бумага", imageAsset: "word_bumaga",
                    isCorrect: correctIndex == 1, form: "бумажный стол")
    ]
    return WhoseRound(
        id: id, subtask: .relativeMaterial, cueImage: "word_stol",
        question: "Из чего сделан стол?", options: options,
        spokenForm: "Стол деревянный.", difficulty: 2, minAge: 6
    )
}

@MainActor
private func makeResponse(
    rounds: [WhoseRound],
    childAge: Int = 6
) -> WhoseTailModels.Start.Response {
    .init(rounds: rounds, soundTarget: "грамматика.притяжат", childAge: childAge)
}

// MARK: - Interactor Tests

@MainActor
final class WhoseTailInteractorTests: XCTestCase {

    private func makeSUT(
        rounds: [WhoseRound],
        childAge: Int = 6
    ) -> (WhoseTailInteractor, SpyWhoseTailPresenter, StubWhoseTailWorker, SpyHapticService, SpyWhoseTailPlanner) {
        let worker = StubWhoseTailWorker(response: makeResponse(rounds: rounds, childAge: childAge))
        let haptic = SpyHapticService()
        let planner = SpyWhoseTailPlanner()
        let sut = WhoseTailInteractor(
            childId: "child-1", worker: worker,
            hapticService: haptic, adaptivePlanner: planner
        )
        let spy = SpyWhoseTailPresenter()
        sut.presenter = spy
        return (sut, spy, worker, haptic, planner)
    }

    // MARK: Start

    func test_start_buildsSessionAndPresents() async {
        let (sut, spy, worker, _, _) = makeSUT(rounds: [makePossessiveRound(), makeRelativeRound()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        XCTAssertEqual(worker.buildCallCount, 1)
        XCTAssertEqual(spy.startCount, 1)
        XCTAssertEqual(sut.rounds.count, 2)
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
        XCTAssertEqual(sut.attemptsInRound, 0)
    }

    func test_start_resetsProgress() async {
        let (sut, _, _, _, _) = makeSUT(rounds: [makePossessiveRound(), makeRelativeRound()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-poss-0", attemptInRound: 1))
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
    }

    func test_start_passesPreferredSubtaskToWorker() async {
        let (sut, _, worker, _, _) = makeSUT(rounds: [makePossessiveRound()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: .animalHome))
        XCTAssertEqual(worker.lastPreferredSubtask, .animalHome)
    }

    // MARK: Option evaluation («светофор»)

    func test_answer_correctOption_isHit_andIncrements() async {
        let (sut, spy, _, haptic, _) = makeSUT(rounds: [makePossessiveRound(correctIndex: 0)])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-poss-0", attemptInRound: 1))
        XCTAssertEqual(sut.correctCount, 1)
        XCTAssertEqual(spy.lastAnswer?.feedback, .hit)
        XCTAssertEqual(spy.lastAnswer?.correctOptionId, "r-poss-0")
        XCTAssertEqual(haptic.notificationCount, 1)
        XCTAssertTrue(spy.lastAnswer?.advancedToNextRound ?? false)
    }

    func test_answer_hit_voicesTargetForm() async {
        // Методическое ядро: на hit система проговаривает целевую форму.
        let (sut, spy, _, _, _) = makeSUT(rounds: [makePossessiveRound(correctIndex: 0)])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-poss-0", attemptInRound: 1))
        XCTAssertEqual(spy.lastAnswer?.spokenForm, "Это лисий хвост.")
    }

    func test_answer_firstMiss_isAlmost_doesNotAdvance() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makePossessiveRound(correctIndex: 0)])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-poss-1", attemptInRound: 1))
        XCTAssertEqual(spy.lastAnswer?.feedback, .almost)
        XCTAssertEqual(sut.correctCount, 0)
        XCTAssertEqual(sut.currentIndex, 0, "Первый промах не продвигает раунд")
        XCTAssertFalse(spy.lastAnswer?.advancedToNextRound ?? true)
        XCTAssertFalse(spy.lastAnswer?.showHint ?? true)
        XCTAssertNil(spy.lastAnswer?.hintOptionId)
        XCTAssertEqual(spy.lastAnswer?.spokenForm, "", "Форму не озвучиваем на промах")
    }

    func test_answer_secondMiss_isRetry_showsHint_andAdvances() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makePossessiveRound(correctIndex: 0), makeRelativeRound()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-poss-1", attemptInRound: 1))
        await sut.answer(request: .init(chosenOptionId: "r-poss-1", attemptInRound: 2))
        XCTAssertEqual(spy.lastAnswer?.feedback, .retry)
        XCTAssertTrue(spy.lastAnswer?.showHint ?? false, "После 2 промахов — подсказка")
        XCTAssertEqual(spy.lastAnswer?.hintOptionId, "r-poss-0", "Подсветка правильного варианта")
        XCTAssertTrue(spy.lastAnswer?.advancedToNextRound ?? false, "Errorless: мягко идём дальше")
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(sut.attemptsInRound, 0, "Счётчик попыток сброшен на новом раунде")
    }

    func test_answer_neverProducesWrongTier() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makePossessiveRound(correctIndex: 0)])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-poss-1", attemptInRound: 1))
        let tier1 = spy.lastAnswer?.feedback
        await sut.answer(request: .init(chosenOptionId: "r-poss-1", attemptInRound: 2))
        let tier2 = spy.lastAnswer?.feedback
        XCTAssertEqual(tier1, .almost)
        XCTAssertEqual(tier2, .retry)
        XCTAssertEqual(Set([FeedbackTier.hit, .almost, .retry]).count, 3)
    }

    // MARK: Verbalisation gate (7–8)

    func test_answer_hit_age7_possessive_asksToRepeat() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makePossessiveRound(correctIndex: 0)], childAge: 7)
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-poss-0", attemptInRound: 1))
        XCTAssertTrue(spy.lastAnswer?.askToRepeat ?? false, "7–8 лет, притяжат. → просим повторить форму")
    }

    func test_answer_hit_age5_doesNotAskToRepeat() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makePossessiveRound(correctIndex: 0)], childAge: 5)
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-poss-0", attemptInRound: 1))
        XCTAssertFalse(spy.lastAnswer?.askToRepeat ?? true)
    }

    func test_answer_hit_age7_relativeMaterial_doesNotAskToRepeat() async {
        // Вербализация не для относительных (форма-конструкция «Стол деревянный»).
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeRelativeRound(correctIndex: 0)], childAge: 7)
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-rel-0", attemptInRound: 1))
        XCTAssertFalse(spy.lastAnswer?.askToRepeat ?? true, "relativeMaterial — без вербализации")
    }

    func test_answer_miss_age7_doesNotAskToRepeat() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makePossessiveRound(correctIndex: 0)], childAge: 7)
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-poss-1", attemptInRound: 1))
        XCTAssertFalse(spy.lastAnswer?.askToRepeat ?? true, "Просьба повторить — только на hit")
    }

    // MARK: Progress / finish

    func test_answer_advancesThroughRounds() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makePossessiveRound(correctIndex: 0), makeRelativeRound()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-poss-0", attemptInRound: 1))
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(spy.lastAnswer?.isFinished, false)
        XCTAssertNotNil(spy.lastAnswer?.nextRound)
        XCTAssertEqual(spy.lastAnswer?.nextRoundIndex, 1)
    }

    func test_answer_lastRound_marksFinished() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makePossessiveRound(correctIndex: 0), makeRelativeRound(correctIndex: 0)])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-poss-0", attemptInRound: 1))
        await sut.answer(request: .init(chosenOptionId: "r-rel-0", attemptInRound: 1))
        XCTAssertEqual(spy.lastAnswer?.isFinished, true)
        XCTAssertNil(spy.lastAnswer?.nextRound)
        XCTAssertEqual(spy.lastAnswer?.correctCount, 2)
        XCTAssertEqual(sut.accuracyFraction, 1.0, accuracy: 0.0001)
    }

    func test_answer_afterFinish_isIgnored() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makePossessiveRound(correctIndex: 0)])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-poss-0", attemptInRound: 1))
        let afterFinish = spy.answerCount
        await sut.answer(request: .init(chosenOptionId: "r-poss-0", attemptInRound: 1))
        XCTAssertEqual(spy.answerCount, afterFinish)
    }

    // MARK: Adaptive (SM-2)

    func test_finish_recordsSessionResult_perfect() async {
        let (sut, _, _, _, planner) = makeSUT(
            rounds: [makePossessiveRound(correctIndex: 0), makeRelativeRound(correctIndex: 0)]
        )
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-poss-0", attemptInRound: 1))
        await sut.answer(request: .init(chosenOptionId: "r-rel-0", attemptInRound: 1))
        XCTAssertEqual(planner.recordCount, 1)
        XCTAssertEqual(planner.lastSound, "грамматика.притяжат")
        XCTAssertEqual(planner.lastQuality, .perfect)
    }

    func test_finish_lowAccuracy_recordsBlackout() async {
        let (sut, _, _, _, planner) = makeSUT(
            rounds: [makePossessiveRound(correctIndex: 0), makeRelativeRound(correctIndex: 0)]
        )
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        // r1: 2 промаха → retry advance (0 правильных).
        await sut.answer(request: .init(chosenOptionId: "r-poss-1", attemptInRound: 1))
        await sut.answer(request: .init(chosenOptionId: "r-poss-1", attemptInRound: 2))
        // r2: 2 промаха → retry advance (0 правильных).
        await sut.answer(request: .init(chosenOptionId: "r-rel-1", attemptInRound: 1))
        await sut.answer(request: .init(chosenOptionId: "r-rel-1", attemptInRound: 2))
        XCTAssertEqual(planner.recordCount, 1)
        XCTAssertEqual(planner.lastQuality, .blackout, "0% → blackout")
    }
}
