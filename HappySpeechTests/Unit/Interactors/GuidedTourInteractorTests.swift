@testable import HappySpeech
import XCTest

// MARK: - GuidedTourInteractorTests
//
// Plan v25 2.8.2 — покрытие GuidedTourInteractor (бизнес-логика тура) до 90%+.
// Тестирует state machine напрямую через Spy presenter:
// loadTour (started/alreadyCompleted/gated/force), nextStep, previousStep,
// skipTour, completeTour, resetTour, autoAdvance (advanced/stale/completed),
// switchFlavor, derived-свойства, persistence resume.

@MainActor
final class GuidedTourInteractorTests: XCTestCase {

    // MARK: - Spy

    @MainActor
    private final class SpyPresenter: GuidedTourPresentationLogic {
        var loadTourCalled = false
        var nextStepCalled = false
        var previousStepCalled = false
        var skipTourCalled = false
        var completeTourCalled = false
        var resetTourCalled = false
        var autoAdvanceCalled = false

        var lastLoadTour: GuidedTourModels.LoadTour.Response?
        var lastNextStep: GuidedTourModels.NextStep.Response?
        var lastPreviousStep: GuidedTourModels.PreviousStep.Response?
        var lastSkipTour: GuidedTourModels.SkipTour.Response?
        var lastCompleteTour: GuidedTourModels.CompleteTour.Response?
        var lastAutoAdvance: GuidedTourModels.AutoAdvance.Response?

        func presentLoadTour(_ response: GuidedTourModels.LoadTour.Response) {
            loadTourCalled = true
            lastLoadTour = response
        }
        func presentNextStep(_ response: GuidedTourModels.NextStep.Response) {
            nextStepCalled = true
            lastNextStep = response
        }
        func presentPreviousStep(_ response: GuidedTourModels.PreviousStep.Response) {
            previousStepCalled = true
            lastPreviousStep = response
        }
        func presentSkipTour(_ response: GuidedTourModels.SkipTour.Response) {
            skipTourCalled = true
            lastSkipTour = response
        }
        func presentCompleteTour(_ response: GuidedTourModels.CompleteTour.Response) {
            completeTourCalled = true
            lastCompleteTour = response
        }
        func presentResetTour(_ response: GuidedTourModels.ResetTour.Response) {
            resetTourCalled = true
        }
        func presentAutoAdvance(_ response: GuidedTourModels.AutoAdvance.Response) {
            autoAdvanceCalled = true
            lastAutoAdvance = response
        }
    }

    // MARK: - Fixtures

    private static let testSteps: [TourStep] = [
        TourStep(id: "a", title: "A", body: "bodyA", highlightKey: "a",
                 lyalyaPhrase: nil, autoAdvanceAfter: nil, allowSkip: true),
        TourStep(id: "b", title: "B", body: "bodyB", highlightKey: "b",
                 lyalyaPhrase: nil, autoAdvanceAfter: nil, allowSkip: true),
        TourStep(id: "c", title: "C", body: "bodyC", highlightKey: "c",
                 lyalyaPhrase: nil, autoAdvanceAfter: nil, allowSkip: false)
    ]

    private func makeSUT(
        steps: [TourStep]? = GuidedTourInteractorTests.testSteps,
        gatingThreshold: Int = 0,
        sessionRepository: (any SessionRepository)? = nil
    ) -> (GuidedTourInteractor, SpyPresenter, UserDefaults) {
        let suiteName = "tour-int-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let sut = GuidedTourInteractor(
            soundService: MockSoundService(),
            analyticsService: MockAnalyticsService(),
            sessionRepository: sessionRepository,
            defaults: defaults,
            gatingThreshold: gatingThreshold,
            flavor: .onboarding,
            steps: steps
        )
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy, defaults)
    }

    // MARK: - 1. loadTour стартует тур с шага 0

    func test_loadTour_startsAtStepZero() {
        let (sut, spy, _) = makeSUT()
        sut.loadTour(.init())
        XCTAssertTrue(spy.loadTourCalled)
        XCTAssertEqual(spy.lastLoadTour?.initialIndex, 0)
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertTrue(sut.isActive)
    }

    // MARK: - 2. loadTour дважды — второй вызов no-op

    func test_loadTour_whenActive_secondCallIgnored() {
        let (sut, spy, _) = makeSUT()
        sut.loadTour(.init())
        spy.loadTourCalled = false
        sut.loadTour(.init())
        XCTAssertFalse(spy.loadTourCalled)
    }

    // MARK: - 3. loadTour завершённого тура → alreadyCompleted

    func test_loadTour_completedTour_returnsAlreadyCompleted() {
        let (sut, spy, _) = makeSUT()
        sut.loadTour(.init())
        sut.completeTour(.init())
        spy.loadTourCalled = false
        sut.loadTour(.init())
        XCTAssertTrue(spy.loadTourCalled)
        if case .alreadyCompleted = spy.lastLoadTour?.kind {
            // ok
        } else {
            XCTFail("Ожидалось alreadyCompleted")
        }
    }

    // MARK: - 4. loadTour force обходит completed

    func test_loadTour_force_bypassesCompleted() {
        let (sut, spy, _) = makeSUT()
        sut.loadTour(.init())
        sut.completeTour(.init())
        spy.loadTourCalled = false
        sut.loadTour(.init(force: true))
        if case .started = spy.lastLoadTour?.kind {
            // ok
        } else {
            XCTFail("Ожидалось started при force")
        }
    }

    // MARK: - 5. loadTour gating — мало сессий → gatedBySessionCount

    func test_loadTour_gatedBySessionCount() async throws {
        let repo = SpySessionRepository(sessions: [])
        let (sut, spy, _) = makeSUT(gatingThreshold: 3, sessionRepository: repo)
        sut.loadTour(.init(childId: "child-1"))
        try await Task.sleep(nanoseconds: 300_000_000)
        if case .gatedBySessionCount = spy.lastLoadTour?.kind {
            // ok
        } else {
            XCTFail("Ожидалось gatedBySessionCount")
        }
    }

    // MARK: - 6. loadTour gating — достаточно сессий → started

    func test_loadTour_enoughSessions_starts() async throws {
        let sessions = (0..<5).map { _ in
            TestDataBuilder.session(childId: "child-1")
        }
        let repo = SpySessionRepository(sessions: sessions)
        let (sut, spy, _) = makeSUT(gatingThreshold: 3, sessionRepository: repo)
        sut.loadTour(.init(childId: "child-1"))
        try await Task.sleep(nanoseconds: 300_000_000)
        if case .started = spy.lastLoadTour?.kind {
            // ok
        } else {
            XCTFail("Ожидалось started")
        }
    }

    // MARK: - 7. nextStep продвигает шаг

    func test_nextStep_advances() {
        let (sut, spy, _) = makeSUT()
        sut.loadTour(.init())
        sut.nextStep(.init())
        XCTAssertTrue(spy.nextStepCalled)
        XCTAssertEqual(spy.lastNextStep?.newIndex, 1)
        XCTAssertEqual(sut.currentIndex, 1)
    }

    // MARK: - 8. nextStep на последнем шаге завершает тур

    func test_nextStep_atLastStep_completes() {
        let (sut, spy, _) = makeSUT()
        sut.loadTour(.init())
        sut.nextStep(.init())  // 1
        sut.nextStep(.init())  // 2
        sut.nextStep(.init())  // выход за пределы → completed
        if case .completed = spy.lastNextStep?.kind {
            // ok
        } else {
            XCTFail("Ожидалось completed")
        }
        XCTAssertFalse(sut.isActive)
    }

    // MARK: - 9. nextStep без активного тура → noop

    func test_nextStep_notActive_noop() {
        let (sut, spy, _) = makeSUT()
        sut.nextStep(.init())
        if case .noop = spy.lastNextStep?.kind {
            // ok
        } else {
            XCTFail("Ожидалось noop")
        }
    }

    // MARK: - 10. previousStep возвращает на шаг назад

    func test_previousStep_retreats() {
        let (sut, spy, _) = makeSUT()
        sut.loadTour(.init())
        sut.nextStep(.init())
        sut.previousStep(.init())
        XCTAssertTrue(spy.previousStepCalled)
        XCTAssertEqual(spy.lastPreviousStep?.newIndex, 0)
        XCTAssertEqual(sut.currentIndex, 0)
    }

    // MARK: - 11. previousStep на первом шаге → atFirstStep

    func test_previousStep_atFirstStep() {
        let (sut, spy, _) = makeSUT()
        sut.loadTour(.init())
        sut.previousStep(.init())
        if case .atFirstStep = spy.lastPreviousStep?.kind {
            // ok
        } else {
            XCTFail("Ожидалось atFirstStep")
        }
    }

    // MARK: - 12. previousStep без активного тура → noop

    func test_previousStep_notActive_noop() {
        let (sut, spy, _) = makeSUT()
        sut.previousStep(.init())
        if case .noop = spy.lastPreviousStep?.kind {
            // ok
        } else {
            XCTFail("Ожидалось noop")
        }
    }

    // MARK: - 13. skipTour завершает тур

    func test_skipTour_completesTour() {
        let (sut, spy, _) = makeSUT()
        sut.loadTour(.init())
        sut.nextStep(.init())
        sut.skipTour(.init())
        XCTAssertTrue(spy.skipTourCalled)
        XCTAssertEqual(spy.lastSkipTour?.skippedAtIndex, 1)
        XCTAssertEqual(spy.lastSkipTour?.totalSteps, 3)
        XCTAssertTrue(sut.hasCompletedCurrentFlavor)
    }

    // MARK: - 14. completeTour помечает тур завершённым

    func test_completeTour_marksCompleted() {
        let (sut, spy, _) = makeSUT()
        sut.loadTour(.init())
        sut.completeTour(.init())
        XCTAssertTrue(spy.completeTourCalled)
        XCTAssertTrue(sut.hasCompletedCurrentFlavor)
        XCTAssertFalse(sut.isActive)
    }

    // MARK: - 15. resetTour сбрасывает состояние

    func test_resetTour_resetsState() {
        let (sut, spy, _) = makeSUT()
        sut.loadTour(.init())
        sut.completeTour(.init())
        sut.resetTour(.init())
        XCTAssertTrue(spy.resetTourCalled)
        XCTAssertFalse(sut.hasCompletedCurrentFlavor)
        XCTAssertNil(sut.currentIndex)
    }

    // MARK: - 16. autoAdvance продвигает при совпадении индекса

    func test_autoAdvance_matchingIndex_advances() {
        let (sut, spy, _) = makeSUT()
        sut.loadTour(.init())
        sut.autoAdvance(.init(scheduledForIndex: 0))
        if case .advanced = spy.lastAutoAdvance?.kind {
            // ok
        } else {
            XCTFail("Ожидалось advanced")
        }
        XCTAssertEqual(sut.currentIndex, 1)
    }

    // MARK: - 17. autoAdvance с несовпадающим индексом → stale

    func test_autoAdvance_staleIndex_noop() {
        let (sut, spy, _) = makeSUT()
        sut.loadTour(.init())
        sut.nextStep(.init())  // currentIndex = 1
        sut.autoAdvance(.init(scheduledForIndex: 0))  // запланирован на 0
        if case .stale = spy.lastAutoAdvance?.kind {
            // ok
        } else {
            XCTFail("Ожидалось stale")
        }
    }

    // MARK: - 18. autoAdvance на последнем шаге → completed

    func test_autoAdvance_atLastStep_completes() {
        let (sut, spy, _) = makeSUT()
        sut.loadTour(.init())
        sut.nextStep(.init())  // 1
        sut.nextStep(.init())  // 2
        sut.autoAdvance(.init(scheduledForIndex: 2))
        if case .completed = spy.lastAutoAdvance?.kind {
            // ok
        } else {
            XCTFail("Ожидалось completed")
        }
    }

    // MARK: - 19. switchFlavor меняет flavor и сбрасывает состояние

    func test_switchFlavor_resetsState() {
        let (sut, _, _) = makeSUT(steps: nil)
        sut.loadTour(.init())
        sut.switchFlavor(.settings)
        XCTAssertNil(sut.currentIndex)
        XCTAssertFalse(sut.isActive)
        XCTAssertFalse(sut.steps.isEmpty)
    }

    // MARK: - 20. derived-свойства

    func test_derivedProperties_currentStepAndProgress() {
        let (sut, _, _) = makeSUT()
        XCTAssertNil(sut.currentStep)
        XCTAssertEqual(sut.progressFraction, 0)
        XCTAssertFalse(sut.isOnLastStep)

        sut.loadTour(.init())
        XCTAssertEqual(sut.currentStep?.id, "a")
        XCTAssertGreaterThan(sut.progressFraction, 0)

        sut.nextStep(.init())
        sut.nextStep(.init())
        XCTAssertTrue(sut.isOnLastStep)
        XCTAssertEqual(sut.progressFraction, 1.0, accuracy: 0.001)
    }

    // MARK: - 21. persistence resume — повторный запуск стартует с прерванного шага

    func test_loadTour_resumesFromSavedIndex() {
        let suiteName = "tour-resume-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let first = GuidedTourInteractor(
            soundService: MockSoundService(),
            analyticsService: MockAnalyticsService(),
            defaults: defaults,
            gatingThreshold: 0,
            flavor: .onboarding,
            steps: Self.testSteps
        )
        let firstSpy = SpyPresenter()
        first.presenter = firstSpy
        first.loadTour(.init())
        first.nextStep(.init())  // resumeIndex = 1

        // Новый Interactor на тех же defaults — должен резюмировать с 1.
        let second = GuidedTourInteractor(
            soundService: MockSoundService(),
            analyticsService: MockAnalyticsService(),
            defaults: defaults,
            gatingThreshold: 0,
            flavor: .onboarding,
            steps: Self.testSteps
        )
        let secondSpy = SpyPresenter()
        second.presenter = secondSpy
        second.loadTour(.init())
        XCTAssertEqual(secondSpy.lastLoadTour?.initialIndex, 1)
    }

    // MARK: - 22. nil steps → дефолтный onboarding-список

    func test_init_nilSteps_usesOnboardingSteps() {
        let (sut, _, _) = makeSUT(steps: nil)
        XCTAssertFalse(sut.steps.isEmpty)
    }
}
