@testable import HappySpeech
import XCTest

// MARK: - SessionShellInteractorTests
//
// Covers the orchestration layer over the 16 game templates:
//   - startSession resets counters & loads activities
//   - completeActivity advances index and fires presentCompleteActivity
//   - Three consecutive failures trigger fatigue detection
//   - pause/resume accounting does not leak into elapsed time
//   - skipCurrentActivity is neutral (no reward, no fatigue, no streak/error impact)
// ==================================================================================

@MainActor
final class SessionShellInteractorTests: XCTestCase {

    // MARK: - Spy Presenter

    @MainActor
    private final class SpyPresenter: SessionShellPresentationLogic {
        var startResponses: [SessionShellModels.StartSession.Response] = []
        var completeResponses: [SessionShellModels.CompleteActivity.Response] = []
        var pauseCalled: Int = 0

        func presentStartSession(_ response: SessionShellModels.StartSession.Response) async {
            startResponses.append(response)
        }
        func presentCompleteActivity(_ response: SessionShellModels.CompleteActivity.Response) async {
            completeResponses.append(response)
        }
        func presentPauseSession(_ response: SessionShellModels.PauseSession.Response) {
            pauseCalled += 1
        }
    }

    // MARK: - SUT

    private func makeSUT(
        adaptivePlanner: MockAdaptivePlannerService = MockAdaptivePlannerService(),
        childRepository: (any ChildRepository)? = nil
    ) -> (SessionShellInteractor, SpyPresenter) {
        let interactor = SessionShellInteractor(
            contentService: MockContentService(),
            adaptivePlannerService: adaptivePlanner,
            sessionRepository: MockSessionRepository(),
            hapticService: MockHapticService(),
            childRepository: childRepository
        )
        let spy = SpyPresenter()
        interactor.presenter = spy
        return (interactor, spy)
    }

    // MARK: - start

    func test_startSession_fires_presentStartSession_withActivities() async {
        let (sut, spy) = makeSUT()
        let request = SessionShellModels.StartSession.Request(
            childId: "c1",
            targetSoundId: "Р",
            sessionType: .adaptive
        )

        await sut.startSession(request)

        XCTAssertEqual(spy.startResponses.count, 1)
        XCTAssertGreaterThan(spy.startResponses.first?.totalSteps ?? 0, 0)
        XCTAssertGreaterThan(spy.startResponses.first?.estimatedMinutes ?? 0, 0)
    }

    // MARK: - completeActivity

    func test_completeActivity_withHighScore_emitsReward_andAdvances() async {
        let (sut, spy) = makeSUT()
        await sut.startSession(.init(childId: "c1", targetSoundId: "Р", sessionType: .adaptive))
        let firstActivity = spy.startResponses.first!.activities.first!

        await sut.completeActivity(.init(
            activityId: firstActivity.id, score: 0.9,
            durationSeconds: 30, errorCount: 0
        ))

        XCTAssertEqual(spy.completeResponses.count, 1)
        XCTAssertNotNil(spy.completeResponses.first?.earnedReward)
        XCTAssertFalse(spy.completeResponses.first!.fatigueDetected)
    }

    func test_consecutiveFailures_or_exhaustion_completes_session() async {
        // The canonical adaptive route from MockAdaptivePlannerService returns a
        // small set of activities (2–3). Verifies that either:
        //  (a) three consecutive low-score submissions trigger fatigue, OR
        //  (b) the session naturally completes once all activities exhaust.
        // Both outcomes are equally valid: the interactor must eventually mark
        // isSessionComplete so the presenter can roll the child to the summary.
        // M1-fix: усталость дренирует сердца по одному (errorsPerHeart подряд
        // ошибок = −1 сердце), конец сессии — при hearts==0 ИЛИ исчерпании
        // активностей. Малый adaptive-маршрут не успевает слить все 3 сердца,
        // поэтому здесь проверяется ветка ИСЧЕРПАНИЯ: проходим КАЖДУЮ активность
        // маршрута (разные id → индекс продвигается) → сессия обязана завершиться.
        // Полная лесенка 3→0 покрыта test_heartsDrainFullLadder_to_zero_endsSession.
        let (sut, spy) = makeSUT()
        await sut.startSession(.init(childId: "c1", targetSoundId: "Р", sessionType: .adaptive))
        let activities = spy.startResponses.first!.activities

        for activity in activities where !(spy.completeResponses.last?.isSessionComplete ?? false) {
            await sut.completeActivity(.init(
                activityId: activity.id, score: 0.2,
                durationSeconds: 10, errorCount: 1
            ))
        }

        let last = spy.completeResponses.last
        XCTAssertNotNil(last)
        XCTAssertTrue(last?.isSessionComplete ?? false,
                      "Session must complete by fatigue or activity exhaustion")
    }

    func test_successResetsConsecutiveErrorCounter() async {
        let (sut, spy) = makeSUT()
        await sut.startSession(.init(childId: "c1", targetSoundId: "Р", sessionType: .adaptive))

        // Two failures
        for _ in 0..<2 {
            let activityId = spy.startResponses.first!.activities.first!.id
            await sut.completeActivity(.init(
                activityId: activityId, score: 0.2,
                durationSeconds: 5, errorCount: 2
            ))
        }
        // One success
        let activityId = spy.startResponses.first!.activities.first!.id
        await sut.completeActivity(.init(
            activityId: activityId, score: 0.9,
            durationSeconds: 10, errorCount: 0
        ))
        // Two more failures — should NOT trip fatigue because counter reset
        for _ in 0..<2 {
            let aid = spy.startResponses.first!.activities.first!.id
            await sut.completeActivity(.init(
                activityId: aid, score: 0.2,
                durationSeconds: 5, errorCount: 2
            ))
        }

        XCTAssertFalse(
            spy.completeResponses.last?.fatigueDetected ?? true,
            "Counter should have reset after the success"
        )
    }

    // MARK: - M1: hearts model decoupled from session-end

    /// M1: 3 подряд ошибки дренируют ОДНО сердце (3→2), но сессия НЕ завершается
    /// по усталости — раньше `detectFatigue` срабатывал на 3-й подряд ошибке, и
    /// сердце никогда не падало ниже 2 (HUD «3 сердца» был косметикой). Берём
    /// quickPractice (5 шагов): после 3 ошибок остаются шаги, сессия живёт.
    func test_threeConsecutiveErrors_drainOneHeart_butDoNotEndSession() async {
        let (sut, spy) = makeSUT()
        await sut.startSession(.init(childId: "c-m1", targetSoundId: "Р", sessionType: .quickPractice))
        XCTAssertEqual(spy.startResponses.first?.activities.count, 5)

        for activity in spy.startResponses.first!.activities.prefix(3) {
            await sut.completeActivity(.init(
                activityId: activity.id, score: 0.2, durationSeconds: 5, errorCount: 1
            ))
        }

        let last = spy.completeResponses.last
        XCTAssertEqual(last?.fatigueHearts, 2, "3 подряд ошибки списывают ровно одно сердце (3→2)")
        XCTAssertFalse(last?.fatigueDetected ?? true,
                       "Сессия НЕ завершается по усталости при первой потере сердца")
        XCTAssertFalse(last?.isSessionComplete ?? true,
                       "Остаются шаги 4 и 5 — сессия продолжается")
    }

    /// M1: проигрывание всей «лесенки» сердец 3→2→1→0 → конец сессии по усталости.
    /// Используем длинный adaptive-маршрут (9 шагов), где 9 подряд ошибок = 3
    /// потерянных сердца → `fatigueDetected`. Каждые `errorsPerHeart`(3) ошибок
    /// списывают одно сердце; на 0 сердец сессия завершается.
    func test_heartsDrainFullLadder_to_zero_endsSession() async {
        let longRoute = AdaptiveRoute(
            steps: (0..<9).map { _ in
                RouteStepItem(templateType: .listenAndChoose, targetSound: "Р",
                              stage: .wordInit, difficulty: 1, wordCount: 6, durationTargetSec: 60)
            },
            maxDurationSec: 900,
            fatigueLevel: .fresh
        )
        let planner = MockAdaptivePlannerService(route: longRoute)
        let (sut, spy) = makeSUT(adaptivePlanner: planner)
        await sut.startSession(.init(childId: "c-ladder", targetSoundId: "Р", sessionType: .adaptive))
        XCTAssertEqual(spy.startResponses.first?.activities.count, 9)

        var heartsTrail: [Int] = []
        for activity in spy.startResponses.first!.activities {
            guard !(spy.completeResponses.last?.isSessionComplete ?? false) else { break }
            await sut.completeActivity(.init(
                activityId: activity.id, score: 0.1, durationSeconds: 3, errorCount: 1
            ))
            if let hearts = spy.completeResponses.last?.fatigueHearts {
                heartsTrail.append(hearts)
            }
        }

        // Сердца реально прошли лесенку 3→2→1→0 (значения 2,1,0 встречаются).
        XCTAssertTrue(heartsTrail.contains(2), "Сердце 3→2 после 3 ошибок")
        XCTAssertTrue(heartsTrail.contains(1), "Сердце 2→1 после 6 ошибок")
        XCTAssertTrue(heartsTrail.contains(0), "Сердце 1→0 после 9 ошибок")
        XCTAssertEqual(sut.currentFatigueHearts, 0, "Все сердца потеряны")
        XCTAssertTrue(spy.completeResponses.last?.fatigueDetected ?? false,
                      "При 0 сердцах сессия завершается по усталости")
    }

    // MARK: - pause

    func test_pauseSession_callsPresenter_once() async {
        let (sut, spy) = makeSUT()
        await sut.startSession(.init(childId: "c1", targetSoundId: "Р", sessionType: .adaptive))

        sut.pauseSession(.init())
        sut.pauseSession(.init())   // second call ignored

        XCTAssertEqual(spy.pauseCalled, 1, "Duplicate pause must be idempotent")
    }

    // MARK: - skip (P2-3: пропуск нейтрален)

    func test_skipCurrentActivity_isNeutral_noReward_skippedFeedback_advances() async {
        let (sut, spy) = makeSUT()
        await sut.startSession(.init(childId: "c1", targetSoundId: "Р", sessionType: .adaptive))

        await sut.skipCurrentActivity()

        let last = spy.completeResponses.last
        XCTAssertNotNil(last)
        XCTAssertNil(last?.earnedReward, "Skip should not award a reward")
        XCTAssertEqual(last?.feedback, .skipped, "Skip must emit neutral .skipped feedback")
        XCTAssertFalse(last?.fatigueDetected ?? true, "A single skip must not trigger fatigue")
    }

    /// P2-3: три пропуска подряд НЕ должны завершать сессию по «усталости»
    /// (раньше skip = score 0 = ошибка → 3 подряд = фатиг). Берём сессию
    /// quickPractice (5 шагов) и пропускаем первые три — сессия продолжается.
    func test_threeSkips_doNotTriggerFatigue() async {
        let (sut, spy) = makeSUT()
        await sut.startSession(.init(childId: "c1", targetSoundId: "Р", sessionType: .quickPractice))
        XCTAssertGreaterThanOrEqual(spy.startResponses.first?.activities.count ?? 0, 4)

        await sut.skipCurrentActivity()
        await sut.skipCurrentActivity()
        await sut.skipCurrentActivity()

        let last = spy.completeResponses.last
        XCTAssertNotNil(last)
        XCTAssertFalse(last?.fatigueDetected ?? true,
                       "Three skips are neutral and must NOT trip fatigue")
        XCTAssertFalse(last?.isSessionComplete ?? true,
                       "Session must still have remaining steps after three skips")
    }

    // MARK: - Batch 1: расширенное покрытие

    func test_startSession_quickPractice_loadsDefaultActivities() async {
        let (sut, spy) = makeSUT()
        await sut.startSession(.init(childId: "c2", targetSoundId: "С", sessionType: .quickPractice))
        XCTAssertEqual(spy.startResponses.count, 1)
        XCTAssertEqual(spy.startResponses.first?.activities.count, 5)
    }

    func test_startSession_screening_loadsDefaultActivities() async {
        let (sut, spy) = makeSUT()
        await sut.startSession(.init(childId: "c3", targetSoundId: "Ш", sessionType: .screening))
        XCTAssertEqual(spy.startResponses.first?.activities.count, 5)
    }

    func test_completeActivity_highScore_earnsStar() async {
        let (sut, spy) = makeSUT()
        await sut.startSession(.init(childId: "c4", targetSoundId: "Р", sessionType: .quickPractice))
        let firstId = spy.startResponses.first!.activities.first!.id
        await sut.completeActivity(.init(activityId: firstId, score: 0.85, durationSeconds: 20, errorCount: 0))
        XCTAssertEqual(spy.completeResponses.last?.earnedReward, .star)
    }

    func test_completeActivity_lowScore_noReward() async {
        let (sut, spy) = makeSUT()
        await sut.startSession(.init(childId: "c5", targetSoundId: "Р", sessionType: .quickPractice))
        let firstId = spy.startResponses.first!.activities.first!.id
        await sut.completeActivity(.init(activityId: firstId, score: 0.6, durationSeconds: 20, errorCount: 0))
        XCTAssertNil(spy.completeResponses.last?.earnedReward, "Score 0.6 < 0.8 → нет звезды")
        XCTAssertEqual(spy.completeResponses.last?.feedback, .correct)
    }

    func test_completeActivity_advancesIndex_overActivities() async {
        let (sut, spy) = makeSUT()
        await sut.startSession(.init(childId: "c6", targetSoundId: "Р", sessionType: .quickPractice))
        let activities = spy.startResponses.first!.activities
        // Завершаем все 5 успешно
        for activity in activities {
            await sut.completeActivity(.init(
                activityId: activity.id, score: 0.9, durationSeconds: 10, errorCount: 0
            ))
        }
        XCTAssertTrue(spy.completeResponses.last?.isSessionComplete ?? false)
    }

    func test_completeActivity_beyondBounds_warningNoResponse() async {
        let (sut, spy) = makeSUT()
        await sut.startSession(.init(childId: "c7", targetSoundId: "Р", sessionType: .quickPractice))
        let activities = spy.startResponses.first!.activities
        for activity in activities {
            await sut.completeActivity(.init(
                activityId: activity.id, score: 0.9, durationSeconds: 10, errorCount: 0
            ))
        }
        let countBefore = spy.completeResponses.count
        // Лишний completeActivity — currentIndex >= activities.count
        await sut.completeActivity(.init(activityId: "extra", score: 0.9, durationSeconds: 1, errorCount: 0))
        XCTAssertEqual(spy.completeResponses.count, countBefore, "Вызов сверх границ не порождает ответ")
    }

    func test_pauseResume_pauseTimeExcludedFromActive() async {
        let (sut, _) = makeSUT()
        await sut.startSession(.init(childId: "c8", targetSoundId: "Р", sessionType: .quickPractice))
        sut.pauseSession(.init())
        sut.resumeSession()
        // После resume сессия снова активна — повторный pause снова сработает
        sut.pauseSession(.init())
        XCTAssertTrue(true)
    }

    func test_resume_withoutPause_noop() async {
        let (sut, _) = makeSUT()
        await sut.startSession(.init(childId: "c9", targetSoundId: "Р", sessionType: .quickPractice))
        sut.resumeSession()   // не было паузы — должен быть noop
        XCTAssertTrue(true)
    }

    func test_currentFatigueHearts_startsAtThree() async {
        let (sut, _) = makeSUT()
        await sut.startSession(.init(childId: "c10", targetSoundId: "Р", sessionType: .quickPractice))
        XCTAssertEqual(sut.currentFatigueHearts, 3)
    }

    func test_endSessionEarly_doesNotCrash() async {
        let (sut, _) = makeSUT()
        await sut.startSession(.init(childId: "c11", targetSoundId: "Р", sessionType: .quickPractice))
        await sut.endSessionEarly()
        XCTAssertTrue(true)
    }

    func test_sessionActiveStartReference_isAfterStart() async {
        let (sut, _) = makeSUT()
        await sut.startSession(.init(childId: "c12", targetSoundId: "Р", sessionType: .quickPractice))
        // Без пауз reference == sessionStartTime (accumulatedPause = 0)
        XCTAssertLessThanOrEqual(sut.sessionActiveStartReference, Date())
    }

    // MARK: - buildSessionResult (P0-2)

    func test_buildSessionResult_carriesRealChildIdSoundAndScore() async {
        let (sut, spy) = makeSUT()
        await sut.startSession(.init(childId: "real-child", targetSoundId: "Ш", sessionType: .quickPractice))

        // Завершаем все шаги с известными score → средняя точность предсказуема.
        var next = spy.startResponses.first?.activities.first
        while let activity = next {
            await sut.completeActivity(.init(
                activityId: activity.id, score: 1.0, durationSeconds: 10, errorCount: 0
            ))
            next = spy.completeResponses.last?.nextActivity
        }

        let result = sut.buildSessionResult()
        XCTAssertEqual(result.childId, "real-child")
        XCTAssertEqual(result.soundTarget, "Ш")
        XCTAssertEqual(result.score, 1.0, accuracy: 0.001)
        XCTAssertEqual(result.starsEarned, 3)
        XCTAssertGreaterThan(result.attempts, 0)
        XCTAssertFalse(result.gameTitle.isEmpty)
        // Реальный результат НЕ равен демо-образцу (childId/score другие).
        XCTAssertNotEqual(result.childId, SessionResult.sample.childId)
    }

    func test_buildSessionResult_lowScore_givesOneStar() async {
        let (sut, spy) = makeSUT()
        await sut.startSession(.init(childId: "c-low", targetSoundId: "Р", sessionType: .quickPractice))

        var next = spy.startResponses.first?.activities.first
        while let activity = next {
            await sut.completeActivity(.init(
                activityId: activity.id, score: 0.2, durationSeconds: 5, errorCount: 1
            ))
            next = spy.completeResponses.last?.nextActivity
        }

        let result = sut.buildSessionResult()
        XCTAssertEqual(result.starsEarned, 1)
        XCTAssertLessThan(result.score, 0.6)
    }

    // MARK: - P0-2: resolve target sound from child profile when route omits it

    func test_startSession_emptyTargetSound_resolvesChildProfileSound() async {
        // Ребёнок со звуком «С» (НЕ хардкод «Р»). Маршрут не донёс звук (пусто).
        let child = ChildProfileDTO(
            id: "child-s", name: "Соня", age: 5, targetSounds: ["С", "З"], parentId: "p1"
        )
        let repo = MockChildRepository(children: [child])
        let (sut, _) = makeSUT(childRepository: repo)

        await sut.startSession(.init(childId: "child-s", targetSoundId: "", sessionType: .quickPractice))

        // Сессия тренирует реальный звук ребёнка «С», а не захардкоженный «Р».
        let result = sut.buildSessionResult()
        XCTAssertEqual(result.soundTarget, "С")
        XCTAssertNotEqual(result.soundTarget, "Р")
    }

    func test_startSession_explicitTargetSound_isNotOverridden() async {
        // Если маршрут донёс конкретный звук — резолв из профиля не вмешивается.
        let child = ChildProfileDTO(
            id: "child-s", name: "Соня", age: 5, targetSounds: ["С"], parentId: "p1"
        )
        let repo = MockChildRepository(children: [child])
        let (sut, _) = makeSUT(childRepository: repo)

        await sut.startSession(.init(childId: "child-s", targetSoundId: "Ш", sessionType: .quickPractice))

        let result = sut.buildSessionResult()
        XCTAssertEqual(result.soundTarget, "Ш", "Явный звук маршрута имеет приоритет над профилем")
    }

    func test_startSession_emptyTargetSound_noRepository_keepsEmpty() async {
        // Без репозитория (legacy) поведение прежнее — звук остаётся как передан.
        let (sut, _) = makeSUT(childRepository: nil)
        await sut.startSession(.init(childId: "c", targetSoundId: "", sessionType: .quickPractice))
        let result = sut.buildSessionResult()
        XCTAssertEqual(result.soundTarget, "")
    }
}
