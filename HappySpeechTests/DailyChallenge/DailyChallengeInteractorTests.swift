@testable import HappySpeech
import XCTest

// MARK: - Stub StatsWorker

@MainActor
private final class StubDailyChallengeStatsWorker: DailyChallengeStatsWorkerProtocol {
    var todaySessions: [SessionDTO] = []
    var stubbedProgress: Int = 0
    var stubbedStreak = StreakState(current: 0, longest: 0, lastSessionISO: nil)

    private(set) var fetchTodayCallCount = 0
    private(set) var progressCallCount = 0
    private(set) var computeStreakCallCount = 0

    func fetchTodaySessions(childId: String, day: Date) async -> [SessionDTO] {
        fetchTodayCallCount += 1
        return todaySessions
    }
    func progress(for kind: DailyGoalKind, targetSound: String, sessions: [SessionDTO]) -> Int {
        progressCallCount += 1
        return stubbedProgress
    }
    func computeStreak(childId: String) async -> StreakState {
        computeStreakCallCount += 1
        return stubbedStreak
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyDailyChallengePresenter: DailyChallengePresentationLogic, @unchecked Sendable {
    var loadCallCount = 0
    var startSessionCallCount = 0
    var shareCallCount = 0

    var lastLoad: DailyChallengeModels.Load.Response?
    var lastStart: DailyChallengeModels.StartSession.Response?
    var lastShare: DailyChallengeModels.ShareCompletion.Response?

    func presentLoad(response: DailyChallengeModels.Load.Response) async {
        loadCallCount += 1
        lastLoad = response
    }
    func presentStartSession(response: DailyChallengeModels.StartSession.Response) async {
        startSessionCallCount += 1
        lastStart = response
    }
    func presentShareCompletion(response: DailyChallengeModels.ShareCompletion.Response) async {
        shareCallCount += 1
        lastShare = response
    }
}

// MARK: - Tests

@MainActor
final class DailyChallengeInteractorTests: XCTestCase {

    private func makeSUT(
        children: [ChildProfileDTO] = [TestDataBuilder.childProfile(id: "c1", name: "Маша", age: 6)],
        fixedDate: Date = Date(timeIntervalSince1970: 1_715_000_000) // 2024-05-06 Mon
    ) -> (DailyChallengeInteractor, SpyDailyChallengePresenter, StubDailyChallengeStatsWorker, SpyHapticService) {
        let worker = StubDailyChallengeStatsWorker()
        let childRepo = SpyChildRepository(children: children)
        let haptic = SpyHapticService()
        let sut = DailyChallengeInteractor(
            statsWorker: worker,
            childRepository: childRepo,
            hapticService: haptic,
            now: { fixedDate }
        )
        let spy = SpyDailyChallengePresenter()
        sut.presenter = spy
        return (sut, spy, worker, haptic)
    }

    // MARK: - load

    func test_load_emitsResponse() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.load(request: .init(childId: "c1"))
        XCTAssertEqual(spy.loadCallCount, 1)
        XCTAssertEqual(spy.lastLoad?.childDisplayName, "Маша")
    }

    func test_load_storesCurrentChildIdAndGoal() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.load(request: .init(childId: "c1"))
        XCTAssertEqual(sut.currentChildId, "c1")
        XCTAssertNotNil(sut.currentGoal)
        XCTAssertEqual(sut.currentGoal?.id, spy.lastLoad?.goal.id)
    }

    func test_load_unknownChild_doesNotEmit() async {
        let (sut, spy, _, _) = makeSUT(children: [])
        await sut.load(request: .init(childId: "missing"))
        XCTAssertEqual(spy.loadCallCount, 0)
    }

    func test_load_usesWorkerProgress() async {
        let (sut, spy, worker, _) = makeSUT()
        worker.stubbedProgress = 100 // больше любого target → isCompleted
        await sut.load(request: .init(childId: "c1"))
        XCTAssertTrue(spy.lastLoad?.goal.isCompleted ?? false)
        XCTAssertEqual(worker.progressCallCount, 1)
    }

    func test_load_callsComputeStreak() async {
        let (sut, spy, worker, _) = makeSUT()
        worker.stubbedStreak = StreakState(current: 4, longest: 9, lastSessionISO: nil)
        await sut.load(request: .init(childId: "c1"))
        XCTAssertEqual(worker.computeStreakCallCount, 1)
        XCTAssertEqual(spy.lastLoad?.streak.current, 4)
    }

    func test_load_goalCurrentClampedToTarget() async {
        let (sut, spy, worker, _) = makeSUT()
        worker.stubbedProgress = 999
        await sut.load(request: .init(childId: "c1"))
        let goal = spy.lastLoad?.goal
        XCTAssertEqual(goal?.current, goal?.target)
    }

    func test_load_rewardHasNonEmptySticker() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.load(request: .init(childId: "c1"))
        XCTAssertFalse(spy.lastLoad?.reward.stickerName.isEmpty ?? true)
        XCTAssertGreaterThan(spy.lastLoad?.reward.xpAward ?? 0, 0)
    }

    // MARK: - startSession

    func test_startSession_emitsResponseAndHaptic() async {
        let (sut, spy, _, haptic) = makeSUT()
        await sut.startSession(request: .init(childId: "c1", targetSound: "Р"))
        XCTAssertEqual(spy.startSessionCallCount, 1)
        XCTAssertEqual(spy.lastStart?.targetSound, "Р")
        XCTAssertGreaterThanOrEqual(haptic.impactCount, 1)
    }

    // MARK: - shareCompletion

    func test_shareCompletion_goalNotCompleted_ignored() async {
        let (sut, spy, worker, _) = makeSUT()
        worker.stubbedProgress = 0
        await sut.load(request: .init(childId: "c1"))
        await sut.shareCompletion(request: .init(childId: "c1"))
        XCTAssertEqual(spy.shareCallCount, 0)
    }

    func test_shareCompletion_goalCompleted_emits() async {
        let (sut, spy, worker, haptic) = makeSUT()
        worker.stubbedProgress = 999
        await sut.load(request: .init(childId: "c1"))
        await sut.shareCompletion(request: .init(childId: "c1"))
        XCTAssertEqual(spy.shareCallCount, 1)
        XCTAssertFalse(spy.lastShare?.snapshotText.isEmpty ?? true)
        XCTAssertGreaterThanOrEqual(haptic.notificationCount, 1)
    }

    func test_shareCompletion_withoutLoad_ignored() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.shareCompletion(request: .init(childId: "c1"))
        XCTAssertEqual(spy.shareCallCount, 0)
    }

    // MARK: - DailyChallengeBuilder pure helpers

    func test_builder_kindByWeekday() {
        XCTAssertEqual(DailyChallengeBuilder.kind(forWeekday: 2), .repetitions)
        XCTAssertEqual(DailyChallengeBuilder.kind(forWeekday: 3), .minutes)
        XCTAssertEqual(DailyChallengeBuilder.kind(forWeekday: 4), .soundFocus)
        XCTAssertEqual(DailyChallengeBuilder.kind(forWeekday: 5), .repetitions)
        XCTAssertEqual(DailyChallengeBuilder.kind(forWeekday: 6), .streakKeep)
        XCTAssertEqual(DailyChallengeBuilder.kind(forWeekday: 7), .minutes)
        XCTAssertEqual(DailyChallengeBuilder.kind(forWeekday: 1), .soundFocus)
    }

    func test_builder_targetByAge() {
        XCTAssertEqual(DailyChallengeBuilder.target(forAge: 5, kind: .repetitions), 7)
        XCTAssertEqual(DailyChallengeBuilder.target(forAge: 7, kind: .repetitions), 10)
        XCTAssertEqual(DailyChallengeBuilder.target(forAge: 8, kind: .repetitions), 12)
        XCTAssertEqual(DailyChallengeBuilder.target(forAge: 5, kind: .minutes), 3)
        XCTAssertEqual(DailyChallengeBuilder.target(forAge: 7, kind: .minutes), 5)
        XCTAssertEqual(DailyChallengeBuilder.target(forAge: 8, kind: .minutes), 7)
        XCTAssertEqual(DailyChallengeBuilder.target(forAge: 6, kind: .soundFocus), 3)
        XCTAssertEqual(DailyChallengeBuilder.target(forAge: 6, kind: .streakKeep), 1)
    }

    func test_builder_xpByKind() {
        XCTAssertEqual(DailyChallengeBuilder.xp(forKind: .repetitions), 20)
        XCTAssertEqual(DailyChallengeBuilder.xp(forKind: .minutes), 25)
        XCTAssertEqual(DailyChallengeBuilder.xp(forKind: .soundFocus), 30)
        XCTAssertEqual(DailyChallengeBuilder.xp(forKind: .streakKeep), 15)
    }

    func test_builder_rewardDeterministic() {
        let r1 = DailyChallengeBuilder.reward(forDaySeed: 12345, kind: .soundFocus)
        let r2 = DailyChallengeBuilder.reward(forDaySeed: 12345, kind: .soundFocus)
        XCTAssertEqual(r1, r2)
        XCTAssertTrue(DailyChallengeBuilder.rewardStickers.contains(r1.stickerName))
    }

    func test_builder_rewardHandlesNegativeSeed() {
        let reward = DailyChallengeBuilder.reward(forDaySeed: -987, kind: .minutes)
        XCTAssertTrue(DailyChallengeBuilder.rewardStickers.contains(reward.stickerName))
    }

    func test_builder_makeGoal_completedWhenProgressReachesTarget() {
        let goal = DailyChallengeBuilder.makeGoal(
            childId: "c1", day: Date(), weekday: 2, age: 6,
            targetSound: "С", currentProgress: 7
        )
        XCTAssertTrue(goal.isCompleted)
        XCTAssertEqual(goal.current, 7)
    }

    func test_builder_makeGoal_notCompletedWhenBelowTarget() {
        let goal = DailyChallengeBuilder.makeGoal(
            childId: "c1", day: Date(), weekday: 2, age: 6,
            targetSound: "С", currentProgress: 3
        )
        XCTAssertFalse(goal.isCompleted)
        XCTAssertEqual(goal.current, 3)
    }

    func test_iso8601_dayString_format() {
        let date = Date(timeIntervalSince1970: 1_715_000_000)
        let str = ISO8601DateFormatter.dayString(from: date)
        XCTAssertEqual(str.count, 10, "yyyy-MM-dd")
        XCTAssertTrue(str.contains("-"))
    }

    func test_dailyGoalKind_titleAndSymbolKeysNotEmpty() {
        for kind in DailyGoalKind.allCases {
            XCTAssertFalse(kind.titleKey.isEmpty)
            XCTAssertFalse(kind.symbolName.isEmpty)
        }
    }
}
