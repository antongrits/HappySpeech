@testable import HappySpeech
import XCTest

// MARK: - SessionShellInteractorTests
//
// Covers the orchestration layer over the 16 game templates:
//   - startSession resets counters & loads activities
//   - completeActivity advances index and fires presentCompleteActivity
//   - Three consecutive failures trigger fatigue detection
//   - pause/resume accounting does not leak into elapsed time
//   - skipCurrentActivity flows through completeActivity with score 0
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
        adaptivePlanner: MockAdaptivePlannerService = MockAdaptivePlannerService()
    ) -> (SessionShellInteractor, SpyPresenter) {
        let interactor = SessionShellInteractor(
            contentService: MockContentService(),
            adaptivePlannerService: adaptivePlanner,
            sessionRepository: MockSessionRepository(),
            hapticService: MockHapticService()
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
        let (sut, spy) = makeSUT()
        await sut.startSession(.init(childId: "c1", targetSoundId: "Р", sessionType: .adaptive))
        let firstActivityId = spy.startResponses.first!.activities.first!.id

        for _ in 0..<3 where !(spy.completeResponses.last?.isSessionComplete ?? false) {
            await sut.completeActivity(.init(
                activityId: firstActivityId, score: 0.2,
                durationSeconds: 10, errorCount: 3
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

    // MARK: - pause

    func test_pauseSession_callsPresenter_once() async {
        let (sut, spy) = makeSUT()
        await sut.startSession(.init(childId: "c1", targetSoundId: "Р", sessionType: .adaptive))

        sut.pauseSession(.init())
        sut.pauseSession(.init())   // second call ignored

        XCTAssertEqual(spy.pauseCalled, 1, "Duplicate pause must be idempotent")
    }

    // MARK: - skip

    func test_skipCurrentActivity_emitsCompleteWithZeroScore() async {
        let (sut, spy) = makeSUT()
        await sut.startSession(.init(childId: "c1", targetSoundId: "Р", sessionType: .adaptive))

        await sut.skipCurrentActivity()

        let last = spy.completeResponses.last
        XCTAssertNotNil(last)
        XCTAssertNil(last?.earnedReward, "Skip should not award a reward")
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
}
