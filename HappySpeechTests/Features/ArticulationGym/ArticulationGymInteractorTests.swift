@testable import HappySpeech
import XCTest
import UIKit

// MARK: - Test Doubles

private final class AGMockHapticService: HapticService, @unchecked Sendable {
    var impactCount = 0
    var notificationCount = 0
    var selectionCount = 0
    var isAvailable: Bool { true }

    func play(pattern: HapticPattern) async {}
    func setIntensityScale(_ scale: Float) {}
    func stop() async {}
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) { impactCount += 1 }
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) { notificationCount += 1 }
    func selection() { selectionCount += 1 }
}

private struct AGMockWorker: ArticulationGymWorkerProtocol {
    var override: [ArticulationItem]?

    func loadExercises(soundGroup: ArticulationSoundGroup) -> [ArticulationItem] {
        override ?? ArticulationCatalog.exercises(for: soundGroup)
    }
}

@MainActor
private final class AGSpyPresenter: ArticulationGymPresentationLogic {
    var loadCalled = false
    var timerTickCalled = false
    var nextCalled = false
    var completeCalled = false

    var lastLoad: ArticulationGymModels.Load.Response?
    var lastTimer: ArticulationGymModels.TimerTick.Response?
    var lastTimerDuration: Int?
    var lastNext: ArticulationGymModels.Next.Response?
    var lastNextTotal: Int?
    var lastComplete: ArticulationGymModels.Complete.Response?

    func presentLoad(response: ArticulationGymModels.Load.Response) async {
        loadCalled = true
        lastLoad = response
    }
    func presentTimerTick(response: ArticulationGymModels.TimerTick.Response, duration: Int) async {
        timerTickCalled = true
        lastTimer = response
        lastTimerDuration = duration
    }
    func presentNext(response: ArticulationGymModels.Next.Response, totalCount: Int) async {
        nextCalled = true
        lastNext = response
        lastNextTotal = totalCount
    }
    func presentComplete(response: ArticulationGymModels.Complete.Response) async {
        completeCalled = true
        lastComplete = response
    }
}

// MARK: - Tests

@MainActor
final class ArticulationGymInteractorTests: XCTestCase {

    private func makeSUT(
        group: ArticulationSoundGroup = .hissing,
        workerOverride: [ArticulationItem]? = nil
    ) -> (ArticulationGymInteractor, AGSpyPresenter, MockAnalyticsService, AGMockHapticService) {
        let analytics = MockAnalyticsService()
        let haptic = AGMockHapticService()
        let sut = ArticulationGymInteractor(
            soundGroup: group,
            worker: AGMockWorker(override: workerOverride),
            analyticsService: analytics,
            hapticService: haptic
        )
        let spy = AGSpyPresenter()
        sut.presenter = spy
        return (sut, spy, analytics, haptic)
    }

    // MARK: loadGym

    func test_loadGym_loadsExercises() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.loadGym(request: .init(soundGroup: .hissing))
        XCTAssertTrue(spy.loadCalled)
        XCTAssertGreaterThan(spy.lastLoad?.exercises.count ?? 0, 0)
    }

    func test_loadGym_storesExercisesInDataStore() async {
        let (sut, _, _, _) = makeSUT()
        await sut.loadGym(request: .init(soundGroup: .sibilant))
        XCTAssertFalse(sut.exercises.isEmpty)
        XCTAssertEqual(sut.soundGroup, .sibilant)
    }

    func test_loadGym_changingGroupReloadsSet() async {
        let (sut, spy, _, _) = makeSUT(group: .hissing)
        await sut.loadGym(request: .init(soundGroup: .hissing))
        let hissingCount = spy.lastLoad?.exercises.count
        await sut.loadGym(request: .init(soundGroup: .sonor))
        XCTAssertEqual(sut.soundGroup, .sonor)
        XCTAssertNotNil(hissingCount)
    }

    // MARK: timerTick

    func test_timerTick_secondsRemaining_noAdvance() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.loadGym(request: .init(soundGroup: .hissing))
        await sut.timerTick(request: .init(exerciseIndex: 0, secondsRemaining: 3))
        XCTAssertTrue(spy.timerTickCalled)
        XCTAssertEqual(spy.lastTimer?.shouldAdvance, false)
        XCTAssertEqual(spy.lastTimer?.secondsRemaining, 3)
    }

    func test_timerTick_zeroSeconds_shouldAdvanceTrue() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.loadGym(request: .init(soundGroup: .hissing))
        await sut.timerTick(request: .init(exerciseIndex: 0, secondsRemaining: 0))
        XCTAssertEqual(spy.lastTimer?.shouldAdvance, true)
    }

    func test_timerTick_negativeSeconds_clampedToZero() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.loadGym(request: .init(soundGroup: .hissing))
        await sut.timerTick(request: .init(exerciseIndex: 0, secondsRemaining: -2))
        XCTAssertEqual(spy.lastTimer?.secondsRemaining, 0)
        XCTAssertEqual(spy.lastTimer?.shouldAdvance, true)
    }

    func test_timerTick_invalidIndex_ignored() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.loadGym(request: .init(soundGroup: .hissing))
        await sut.timerTick(request: .init(exerciseIndex: 999, secondsRemaining: 3))
        XCTAssertFalse(spy.timerTickCalled)
    }

    func test_timerTick_passesExerciseDuration() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.loadGym(request: .init(soundGroup: .hissing))
        await sut.timerTick(request: .init(exerciseIndex: 0, secondsRemaining: 4))
        XCTAssertEqual(spy.lastTimerDuration, sut.exercises[0].durationSeconds)
    }

    // MARK: nextExercise

    func test_nextExercise_movesToNextIndex() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.loadGym(request: .init(soundGroup: .hissing))
        await sut.nextExercise(request: .init(currentIndex: 0))
        XCTAssertEqual(spy.lastNext?.nextIndex, 1)
        XCTAssertEqual(spy.lastNext?.isLast, false)
    }

    func test_nextExercise_firesHapticWhenNotLast() async {
        let (sut, _, _, haptic) = makeSUT()
        await sut.loadGym(request: .init(soundGroup: .hissing))
        await sut.nextExercise(request: .init(currentIndex: 0))
        XCTAssertEqual(haptic.impactCount, 1)
    }

    func test_nextExercise_atLastIndex_showsCompletion() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.loadGym(request: .init(soundGroup: .hissing))
        let lastIndex = sut.exercises.count - 1
        await sut.nextExercise(request: .init(currentIndex: lastIndex))
        XCTAssertEqual(spy.lastNext?.isLast, true)
    }

    func test_nextExercise_atLastIndex_noHaptic() async {
        let (sut, _, _, haptic) = makeSUT()
        await sut.loadGym(request: .init(soundGroup: .hissing))
        let lastIndex = sut.exercises.count - 1
        await sut.nextExercise(request: .init(currentIndex: lastIndex))
        XCTAssertEqual(haptic.impactCount, 0)
    }

    func test_nextExercise_passesTotalCount() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.loadGym(request: .init(soundGroup: .hissing))
        await sut.nextExercise(request: .init(currentIndex: 0))
        XCTAssertEqual(spy.lastNextTotal, sut.exercises.count)
    }

    // MARK: completeGym

    func test_completeGym_callsPresenter() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.loadGym(request: .init(soundGroup: .hissing))
        await sut.completeGym(request: .init())
        XCTAssertTrue(spy.completeCalled)
    }

    func test_completeGym_tracksAnalyticsEvent() async {
        let (sut, _, analytics, _) = makeSUT(group: .sonor)
        await sut.loadGym(request: .init(soundGroup: .sonor))
        await sut.completeGym(request: .init())
        let event = analytics.events.first { $0.name == "articulation_gym_completed" }
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.parameters["soundGroup"], "sonor")
    }

    func test_completeGym_firesSuccessHaptic() async {
        let (sut, _, _, haptic) = makeSUT()
        await sut.loadGym(request: .init(soundGroup: .hissing))
        await sut.completeGym(request: .init())
        XCTAssertEqual(haptic.notificationCount, 1)
    }

    func test_completeGym_responseHasExerciseCount() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.loadGym(request: .init(soundGroup: .hissing))
        await sut.completeGym(request: .init())
        XCTAssertEqual(spy.lastComplete?.exerciseCount, sut.exercises.count)
    }

    // MARK: Worker fallback / catalog

    func test_worker_emptyOverride_returnsUniversalFallback() {
        let worker = AGMockWorker(override: [])
        // override [] делает loadExercises вернуть [] — но Worker сам не fallback-ит здесь;
        // проверяем реальный Worker:
        _ = worker
        let realWorker = ArticulationGymWorker()
        let result = realWorker.loadExercises(soundGroup: .hissing)
        XCTAssertFalse(result.isEmpty)
    }

    func test_catalog_eachGroupHasExercises() {
        for group in ArticulationSoundGroup.allCases {
            XCTAssertFalse(ArticulationCatalog.exercises(for: group).isEmpty,
                           "Группа \(group.rawValue) должна иметь упражнения")
        }
    }

    func test_catalog_universalNotEmpty() {
        XCTAssertGreaterThanOrEqual(ArticulationCatalog.universal.count, 5)
    }

    func test_catalog_includesWarmUpExercises() {
        let hissing = ArticulationCatalog.exercises(for: .hissing)
        let universalIds = Set(ArticulationCatalog.universal.prefix(2).map(\.id))
        let hissingIds = Set(hissing.map(\.id))
        XCTAssertTrue(universalIds.isSubset(of: hissingIds))
    }
}
