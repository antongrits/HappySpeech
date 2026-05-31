@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubWordFormationWorker: WordFormationWorkerProtocol {
    var response: WordFormationModels.Start.Response
    private(set) var buildCallCount = 0
    private(set) var lastPreferredSubtask: FormationSubtask?

    init(response: WordFormationModels.Start.Response) {
        self.response = response
    }

    func buildSession(
        childId: String,
        preferredSubtask: FormationSubtask?
    ) async -> WordFormationModels.Start.Response {
        buildCallCount += 1
        lastPreferredSubtask = preferredSubtask
        return response
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyWordFormationPresenter: WordFormationPresentationLogic, @unchecked Sendable {
    var startCount = 0
    var answerCount = 0
    var lastAnswer: WordFormationModels.Answer.Response?

    func presentStart(response: WordFormationModels.Start.Response) async {
        startCount += 1
    }
    func presentAnswer(response: WordFormationModels.Answer.Response) async {
        answerCount += 1
        lastAnswer = response
    }
}

// MARK: - Spy AdaptivePlanner

private final class SpyWordFormationPlanner: AdaptivePlannerService, @unchecked Sendable {
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
private func makeDiminutiveRound(
    id: String = "r-dim",
    correctIndex: Int = 0
) -> FormationRound {
    let options = [
        FormationOption(id: "\(id)-0", text: "столик", isCorrect: correctIndex == 0),
        FormationOption(id: "\(id)-1", text: "столёнок", isCorrect: correctIndex == 1)
    ]
    return FormationRound(
        id: id, subtask: .diminutive, baseWord: "стол", baseImage: "word_stol",
        prompt: "Назови ласково", options: options, spokenForm: "Столик.",
        difficulty: 1, minAge: 5
    )
}

@MainActor
private func makeManyOfRound(
    id: String = "r-many",
    correctIndex: Int = 0
) -> FormationRound {
    // idx0 — норма; idx1 — близкая ошибка (nearMiss); idx2 — грубая.
    let options = [
        FormationOption(id: "\(id)-0", text: "много стульев", isCorrect: correctIndex == 0),
        FormationOption(id: "\(id)-1", text: "много стулов", isCorrect: correctIndex == 1, isNearMiss: true),
        FormationOption(id: "\(id)-2", text: "много стулья", isCorrect: correctIndex == 2)
    ]
    return FormationRound(
        id: id, subtask: .manyOf, baseWord: "стул", baseImage: "word_stul",
        prompt: "Чего много?", options: options, spokenForm: "Много стульев.",
        difficulty: 3, minAge: 6
    )
}

@MainActor
private func makeResponse(
    rounds: [FormationRound],
    childAge: Int = 6
) -> WordFormationModels.Start.Response {
    .init(rounds: rounds, soundTarget: "грамматика.словообр", childAge: childAge)
}

// MARK: - Interactor Tests

@MainActor
final class WordFormationInteractorTests: XCTestCase {

    private func makeSUT(
        rounds: [FormationRound],
        childAge: Int = 6
    ) -> (WordFormationInteractor, SpyWordFormationPresenter, StubWordFormationWorker, SpyHapticService, SpyWordFormationPlanner) {
        let worker = StubWordFormationWorker(response: makeResponse(rounds: rounds, childAge: childAge))
        let haptic = SpyHapticService()
        let planner = SpyWordFormationPlanner()
        let sut = WordFormationInteractor(
            childId: "child-1", worker: worker,
            hapticService: haptic, adaptivePlanner: planner
        )
        let spy = SpyWordFormationPresenter()
        sut.presenter = spy
        return (sut, spy, worker, haptic, planner)
    }

    // MARK: Start

    func test_start_buildsSessionAndPresents() async {
        let (sut, spy, worker, _, _) = makeSUT(rounds: [makeDiminutiveRound(), makeManyOfRound()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        XCTAssertEqual(worker.buildCallCount, 1)
        XCTAssertEqual(spy.startCount, 1)
        XCTAssertEqual(sut.rounds.count, 2)
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
        XCTAssertEqual(sut.attemptsInRound, 0)
    }

    func test_start_resetsProgress() async {
        let (sut, _, _, _, _) = makeSUT(rounds: [makeDiminutiveRound(), makeManyOfRound()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-dim-0", attemptInRound: 1))
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
    }

    func test_start_passesPreferredSubtaskToWorker() async {
        let (sut, _, worker, _, _) = makeSUT(rounds: [makeDiminutiveRound()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: .manyOf))
        XCTAssertEqual(worker.lastPreferredSubtask, .manyOf)
    }

    // MARK: Option evaluation («светофор»)

    func test_answer_correctForm_isHit_andIncrements() async {
        let (sut, spy, _, haptic, _) = makeSUT(rounds: [makeDiminutiveRound(correctIndex: 0)])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-dim-0", attemptInRound: 1))
        XCTAssertEqual(sut.correctCount, 1)
        XCTAssertEqual(spy.lastAnswer?.feedback, .hit)
        XCTAssertEqual(spy.lastAnswer?.correctOptionId, "r-dim-0")
        XCTAssertEqual(haptic.notificationCount, 1)
        XCTAssertTrue(spy.lastAnswer?.advancedToNextRound ?? false)
    }

    func test_answer_hit_voicesNormativeForm() async {
        // Методическое ядро: на hit система проговаривает нормативную форму.
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeManyOfRound(correctIndex: 0)])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-many-0", attemptInRound: 1))
        XCTAssertEqual(spy.lastAnswer?.spokenForm, "Много стульев.")
    }

    func test_answer_firstMiss_isAlmost_doesNotAdvance() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeDiminutiveRound(correctIndex: 0)])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        // Выбираем дистрактор (idx 1).
        await sut.answer(request: .init(chosenOptionId: "r-dim-1", attemptInRound: 1))
        XCTAssertEqual(spy.lastAnswer?.feedback, .almost)
        XCTAssertEqual(sut.correctCount, 0)
        XCTAssertEqual(sut.currentIndex, 0, "Первый промах не продвигает раунд")
        XCTAssertFalse(spy.lastAnswer?.advancedToNextRound ?? true)
        XCTAssertFalse(spy.lastAnswer?.showHint ?? true)
        XCTAssertNil(spy.lastAnswer?.hintOptionId)
        XCTAssertEqual(spy.lastAnswer?.spokenForm, "", "Форму не озвучиваем на промах")
    }

    func test_answer_nearMissDistractor_flaggedNearMiss() async {
        // «много стулов» — близкая ошибка (isNearMiss).
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeManyOfRound(correctIndex: 0)])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-many-1", attemptInRound: 1))
        XCTAssertEqual(spy.lastAnswer?.feedback, .almost)
        XCTAssertTrue(spy.lastAnswer?.chosenWasNearMiss ?? false, "«много стулов» — близкая ошибка")
    }

    func test_answer_grossDistractor_notNearMiss() async {
        // «много стулья» — грубая ошибка (без isNearMiss).
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeManyOfRound(correctIndex: 0)])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-many-2", attemptInRound: 1))
        XCTAssertEqual(spy.lastAnswer?.feedback, .almost)
        XCTAssertFalse(spy.lastAnswer?.chosenWasNearMiss ?? true, "«много стулья» — грубая ошибка")
    }

    func test_answer_secondMiss_isRetry_showsHint_andAdvances() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeDiminutiveRound(correctIndex: 0), makeManyOfRound()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-dim-1", attemptInRound: 1))
        await sut.answer(request: .init(chosenOptionId: "r-dim-1", attemptInRound: 2))
        XCTAssertEqual(spy.lastAnswer?.feedback, .retry)
        XCTAssertTrue(spy.lastAnswer?.showHint ?? false, "После 2 промахов — подсказка")
        XCTAssertEqual(spy.lastAnswer?.hintOptionId, "r-dim-0", "Подсветка нормативной формы")
        XCTAssertTrue(spy.lastAnswer?.advancedToNextRound ?? false, "Errorless: мягко идём дальше")
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(sut.attemptsInRound, 0, "Счётчик попыток сброшен на новом раунде")
    }

    func test_answer_neverProducesWrongTier() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeDiminutiveRound(correctIndex: 0)])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-dim-1", attemptInRound: 1))
        let tier1 = spy.lastAnswer?.feedback
        await sut.answer(request: .init(chosenOptionId: "r-dim-1", attemptInRound: 2))
        let tier2 = spy.lastAnswer?.feedback
        XCTAssertEqual(tier1, .almost)
        XCTAssertEqual(tier2, .retry)
        XCTAssertEqual(Set([FeedbackTier.hit, .almost, .retry]).count, 3)
    }

    // MARK: Verbalisation gate (7–8)

    func test_answer_hit_age7_asksToRepeat() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeDiminutiveRound(correctIndex: 0)], childAge: 7)
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-dim-0", attemptInRound: 1))
        XCTAssertTrue(spy.lastAnswer?.askToRepeat ?? false, "7–8 лет → просим повторить форму")
    }

    func test_answer_hit_age5_doesNotAskToRepeat() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeDiminutiveRound(correctIndex: 0)], childAge: 5)
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-dim-0", attemptInRound: 1))
        XCTAssertFalse(spy.lastAnswer?.askToRepeat ?? true)
    }

    func test_answer_miss_age7_doesNotAskToRepeat() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeDiminutiveRound(correctIndex: 0)], childAge: 7)
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-dim-1", attemptInRound: 1))
        XCTAssertFalse(spy.lastAnswer?.askToRepeat ?? true, "Просьба повторить — только на hit")
    }

    // MARK: Progress / finish

    func test_answer_advancesThroughRounds() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeDiminutiveRound(correctIndex: 0), makeManyOfRound()])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-dim-0", attemptInRound: 1))
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(spy.lastAnswer?.isFinished, false)
        XCTAssertNotNil(spy.lastAnswer?.nextRound)
        XCTAssertEqual(spy.lastAnswer?.nextRoundIndex, 1)
    }

    func test_answer_lastRound_marksFinished() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeDiminutiveRound(correctIndex: 0), makeManyOfRound(correctIndex: 0)])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-dim-0", attemptInRound: 1))
        await sut.answer(request: .init(chosenOptionId: "r-many-0", attemptInRound: 1))
        XCTAssertEqual(spy.lastAnswer?.isFinished, true)
        XCTAssertNil(spy.lastAnswer?.nextRound)
        XCTAssertEqual(spy.lastAnswer?.correctCount, 2)
        XCTAssertEqual(sut.accuracyFraction, 1.0, accuracy: 0.0001)
    }

    func test_answer_afterFinish_isIgnored() async {
        let (sut, spy, _, _, _) = makeSUT(rounds: [makeDiminutiveRound(correctIndex: 0)])
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-dim-0", attemptInRound: 1))
        let afterFinish = spy.answerCount
        await sut.answer(request: .init(chosenOptionId: "r-dim-0", attemptInRound: 1))
        XCTAssertEqual(spy.answerCount, afterFinish)
    }

    // MARK: Adaptive (SM-2)

    func test_finish_recordsSessionResult_perfect() async {
        let (sut, _, _, _, planner) = makeSUT(
            rounds: [makeDiminutiveRound(correctIndex: 0), makeManyOfRound(correctIndex: 0)]
        )
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        await sut.answer(request: .init(chosenOptionId: "r-dim-0", attemptInRound: 1))
        await sut.answer(request: .init(chosenOptionId: "r-many-0", attemptInRound: 1))
        XCTAssertEqual(planner.recordCount, 1)
        XCTAssertEqual(planner.lastSound, "грамматика.словообр")
        XCTAssertEqual(planner.lastQuality, .perfect)
    }

    func test_finish_lowAccuracy_recordsBlackout() async {
        let (sut, _, _, _, planner) = makeSUT(
            rounds: [makeDiminutiveRound(correctIndex: 0), makeManyOfRound(correctIndex: 0)]
        )
        await sut.start(request: .init(childId: "child-1", preferredSubtask: nil))
        // r1: 2 промаха → retry advance (0 правильных).
        await sut.answer(request: .init(chosenOptionId: "r-dim-1", attemptInRound: 1))
        await sut.answer(request: .init(chosenOptionId: "r-dim-1", attemptInRound: 2))
        // r2: 2 промаха → retry advance (0 правильных).
        await sut.answer(request: .init(chosenOptionId: "r-many-1", attemptInRound: 1))
        await sut.answer(request: .init(chosenOptionId: "r-many-2", attemptInRound: 2))
        XCTAssertEqual(planner.recordCount, 1)
        XCTAssertEqual(planner.lastQuality, .blackout, "0% → blackout")
    }
}
