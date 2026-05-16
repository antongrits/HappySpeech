@testable import HappySpeech
import XCTest

// MARK: - DailyStreakInteractorTests
//
// Block 2.8.3 v25 — unit-покрытие DailyStreakInteractor (gamification S.1).
// Паттерн: Interactor → spy на DailyStreakPresentationLogic.
// Persistence — изолированный UserDefaults(suiteName:) на каждый тест.
// Notifications/Haptic — Mock-сервисы.

@MainActor
private final class SpyDailyStreakPresenter: DailyStreakPresentationLogic, @unchecked Sendable {
    var presentLoadCalled = false
    var presentCheckInCalled = false
    var presentUseSaverCalled = false

    var lastLoad: DailyStreakModels.Load.Response?
    var lastCheckIn: DailyStreakModels.CheckIn.Response?
    var lastUseSaver: DailyStreakModels.UseSaver.Response?

    func presentLoad(response: DailyStreakModels.Load.Response) async {
        presentLoadCalled = true
        lastLoad = response
    }
    func presentCheckIn(response: DailyStreakModels.CheckIn.Response) async {
        presentCheckInCalled = true
        lastCheckIn = response
    }
    func presentUseSaver(response: DailyStreakModels.UseSaver.Response) async {
        presentUseSaverCalled = true
        lastUseSaver = response
    }
}

@MainActor
final class DailyStreakInteractorTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "test.dailystreak.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func makeSUT(
        childId: String = "child-ds"
    ) -> (DailyStreakInteractor, SpyDailyStreakPresenter, MockNotificationService) {
        let notif = MockNotificationService()
        let sut = DailyStreakInteractor(
            childId: childId,
            notificationService: notif,
            hapticService: MockHapticService(),
            userDefaults: defaults,
            calendar: .current
        )
        let spy = SpyDailyStreakPresenter()
        sut.presenter = spy
        return (sut, spy, notif)
    }

    // MARK: - 1. load — свежий профиль → fresh status, нулевой стрик

    func test_load_freshProfile_zeroStreak() async {
        let (sut, spy, _) = makeSUT()
        await sut.load(request: .init(childId: "child-ds"))

        XCTAssertTrue(spy.presentLoadCalled)
        XCTAssertEqual(spy.lastLoad?.currentStreak, 0)
        XCTAssertEqual(spy.lastLoad?.longestStreak, 0)
        XCTAssertEqual(spy.lastLoad?.status, .fresh)
        XCTAssertNil(spy.lastLoad?.lastActiveAt)
    }

    // MARK: - 2. load — nextMilestone задан при свежем профиле

    func test_load_freshProfile_nextMilestoneIsFirst() async {
        let (sut, spy, _) = makeSUT()
        await sut.load(request: .init(childId: "child-ds"))

        XCTAssertEqual(spy.lastLoad?.nextMilestone?.days, 3)
        XCTAssertTrue(spy.lastLoad?.unlockedMilestones.isEmpty ?? false)
    }

    // MARK: - 3. checkIn — первый check-in → стрик 1, status active

    func test_checkIn_first_streakBecomesOne() async {
        let (sut, spy, _) = makeSUT()
        await sut.checkIn(request: .init(childId: "child-ds", now: Date()))

        XCTAssertTrue(spy.presentCheckInCalled)
        XCTAssertEqual(spy.lastCheckIn?.newStreak, 1)
        XCTAssertEqual(spy.lastCheckIn?.status, .active)
    }

    // MARK: - 4. checkIn — тот же день дважды → стрик не растёт

    func test_checkIn_sameDayTwice_streakUnchanged() async {
        let (sut, spy, _) = makeSUT()
        let now = Date()
        await sut.checkIn(request: .init(childId: "child-ds", now: now))
        await sut.checkIn(request: .init(childId: "child-ds", now: now))

        XCTAssertEqual(spy.lastCheckIn?.newStreak, 1)
    }

    // MARK: - 5. checkIn — следующий день → стрик растёт

    func test_checkIn_nextDay_streakIncreases() async {
        let (sut, spy, _) = makeSUT()
        let day1 = Date()
        let day2 = Calendar.current.date(byAdding: .day, value: 1, to: day1)!
        await sut.checkIn(request: .init(childId: "child-ds", now: day1))
        await sut.checkIn(request: .init(childId: "child-ds", now: day2))

        XCTAssertEqual(spy.lastCheckIn?.newStreak, 2)
        XCTAssertEqual(spy.lastCheckIn?.status, .active)
    }

    // MARK: - 6. checkIn — пропущенный день → стрик сброшен (broken)

    func test_checkIn_gapDay_streakResets() async {
        let (sut, spy, _) = makeSUT()
        let day1 = Date()
        let day3 = Calendar.current.date(byAdding: .day, value: 3, to: day1)!
        await sut.checkIn(request: .init(childId: "child-ds", now: day1))
        await sut.checkIn(request: .init(childId: "child-ds", now: day3))

        XCTAssertEqual(spy.lastCheckIn?.newStreak, 1)
        XCTAssertEqual(spy.lastCheckIn?.status, .broken)
    }

    // MARK: - 7. checkIn — milestone unlocked при достижении 3 дней

    func test_checkIn_reachesThreeDays_unlocksMilestone() async {
        let (sut, spy, _) = makeSUT()
        var day = Date()
        for _ in 0..<3 {
            await sut.checkIn(request: .init(childId: "child-ds", now: day))
            day = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        }
        XCTAssertEqual(spy.lastCheckIn?.newStreak, 3)
        XCTAssertEqual(spy.lastCheckIn?.unlockedMilestone?.days, 3)
    }

    // MARK: - 8. checkIn — milestone не дублируется при повторном достижении

    func test_checkIn_milestoneNotUnlockedTwice() async {
        let (sut, spy, _) = makeSUT()
        var day = Date()
        for _ in 0..<3 {
            await sut.checkIn(request: .init(childId: "child-ds", now: day))
            day = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        }
        // 4-й check-in: стрик 4, milestone 3 уже разблокирован.
        await sut.checkIn(request: .init(childId: "child-ds", now: day))
        XCTAssertNil(spy.lastCheckIn?.unlockedMilestone)
    }

    // MARK: - 9. load после стрика — longestStreak сохраняется

    func test_load_afterCheckIns_persistsLongest() async {
        let (sut, spy, _) = makeSUT()
        var day = Date()
        for _ in 0..<2 {
            await sut.checkIn(request: .init(childId: "child-ds", now: day))
            day = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        }
        await sut.load(request: .init(childId: "child-ds"))
        XCTAssertEqual(spy.lastLoad?.longestStreak, 2)
    }

    // MARK: - 10. useSaver — первый раз доступен → success

    func test_useSaver_firstTime_succeeds() async {
        let (sut, spy, _) = makeSUT()
        await sut.checkIn(request: .init(childId: "child-ds", now: Date()))
        await sut.useSaver(request: .init(childId: "child-ds", now: Date()))

        XCTAssertTrue(spy.presentUseSaverCalled)
        XCTAssertEqual(spy.lastUseSaver?.success, true)
    }

    // MARK: - 11. useSaver — второй раз в том же месяце → отказ

    func test_useSaver_secondInSameMonth_fails() async {
        let (sut, spy, _) = makeSUT()
        let now = Date()
        await sut.checkIn(request: .init(childId: "child-ds", now: now))
        await sut.useSaver(request: .init(childId: "child-ds", now: now))
        await sut.useSaver(request: .init(childId: "child-ds", now: now))

        XCTAssertEqual(spy.lastUseSaver?.success, false)
    }

    // MARK: - 12. useSaver — nextSaverAvailableAt задан

    func test_useSaver_providesNextAvailableDate() async {
        let (sut, spy, _) = makeSUT()
        await sut.useSaver(request: .init(childId: "child-ds", now: Date()))
        XCTAssertNotNil(spy.lastUseSaver?.nextSaverAvailableAt)
    }

    // MARK: - 13. scheduleReminderIfNeeded — планирует напоминание

    func test_scheduleReminder_schedulesWhenPermitted() async {
        let (sut, _, notif) = makeSUT()
        _ = notif
        await sut.scheduleReminderIfNeeded(childName: "Маша")
        // Идемпотентность: повторный вызов не крашит.
        await sut.scheduleReminderIfNeeded(childName: "Маша")
        XCTAssertTrue(defaults.bool(forKey: "happyspeech.dailyStreak.child-ds.reminderOn"))
    }

    // MARK: - 14. DailyStreakMilestone — каталог из 6 этапов

    func test_milestone_catalogHasSixEntries() {
        XCTAssertEqual(DailyStreakMilestone.all.count, 6)
        XCTAssertEqual(DailyStreakMilestone.all.map(\.days), [3, 7, 14, 30, 60, 100])
    }

    // MARK: - 15. DailyStreakMilestone.unlocked / next

    func test_milestone_unlockedAndNext() {
        XCTAssertEqual(DailyStreakMilestone.unlocked(for: 10).map(\.days), [3, 7])
        XCTAssertEqual(DailyStreakMilestone.next(after: 10)?.days, 14)
        XCTAssertNil(DailyStreakMilestone.next(after: 100))
    }

    // MARK: - 16. DataStore — childId доступен

    func test_dataStore_childIdSet() {
        let (sut, _, _) = makeSUT(childId: "ds-custom")
        XCTAssertEqual(sut.childId, "ds-custom")
    }
}
