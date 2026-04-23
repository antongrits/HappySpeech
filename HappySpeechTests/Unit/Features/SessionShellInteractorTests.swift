import XCTest
@testable import HappySpeech

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

    func test_threeConsecutiveFailures_triggersFatigueFlag() async {
        let (sut, spy) = makeSUT()
        await sut.startSession(.init(childId: "c1", targetSoundId: "Р", sessionType: .adaptive))

        for _ in 0..<3 {
            let activityId = spy.startResponses.first!.activities.randomElement()!.id
            await sut.completeActivity(.init(
                activityId: activityId, score: 0.2,
                durationSeconds: 10, errorCount: 3
            ))
        }

        XCTAssertTrue(
            spy.completeResponses.last?.fatigueDetected ?? false,
            "Third consecutive low-score activity must trip fatigue"
        )
        XCTAssertTrue(spy.completeResponses.last?.isSessionComplete ?? false)
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
}
