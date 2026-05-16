@testable import HappySpeech
import XCTest

// MARK: - FamilyAchievementsInteractorTests
//
// Block 2.8.3 v25 — unit-покрытие FamilyAchievementsInteractor (R.4 v18).
// Паттерн: Interactor → spy на FamilyAchievementsPresentationLogic.
// childRepository/sessionRepository — Mock; persistence — изолированный UserDefaults.

@MainActor
private final class SpyFamilyAchievementsPresenter: FamilyAchievementsPresentationLogic, @unchecked Sendable {
    var presentLoadCalled = false
    var presentRecomputeCalled = false
    var lastLoad: FamilyAchievementsModels.Load.Response?
    var lastRecompute: FamilyAchievementsModels.Recompute.Response?

    func presentLoad(response: FamilyAchievementsModels.Load.Response) async {
        presentLoadCalled = true
        lastLoad = response
    }
    func presentRecompute(response: FamilyAchievementsModels.Recompute.Response) async {
        presentRecomputeCalled = true
        lastRecompute = response
    }
}

@MainActor
final class FamilyAchievementsInteractorTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "test.familyach.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func makeChild(
        id: String,
        streak: Int = 0,
        progressSummary: [String: Double] = [:],
        lastSessionAt: Date? = nil,
        avatarStyle: String = "fox"
    ) -> ChildProfileDTO {
        ChildProfileDTO(
            id: id, name: "Ребёнок-\(id)", age: 6,
            targetSounds: ["Р"], parentId: "family-fa",
            progressSummary: progressSummary,
            avatarStyle: avatarStyle,
            currentStreak: streak,
            lastSessionAt: lastSessionAt
        )
    }

    private func makeSUT(
        children: [ChildProfileDTO],
        sessions: [SessionDTO] = [],
        childRepoFails: Bool = false
    ) -> (FamilyAchievementsInteractor, SpyFamilyAchievementsPresenter) {
        let childRepo = MockChildRepository(children: children)
        childRepo.shouldFail = childRepoFails
        let sessionRepo = MockSessionRepository(sessions: sessions)
        let sut = FamilyAchievementsInteractor(
            familyId: "family-fa",
            childRepository: childRepo,
            sessionRepository: sessionRepo,
            hapticService: MockHapticService(),
            userDefaults: defaults
        )
        let spy = SpyFamilyAchievementsPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. load — каталог достижений всегда полный

    func test_load_returnsFullCatalog() async {
        let (sut, spy) = makeSUT(children: [makeChild(id: "c1")])
        await sut.load(request: .init(familyId: "family-fa"))

        XCTAssertTrue(spy.presentLoadCalled)
        XCTAssertEqual(spy.lastLoad?.achievements.count, FamilyAchievement.catalog.count)
    }

    // MARK: - 2. load — member summaries по каждому ребёнку

    func test_load_buildsMemberSummaries() async {
        let children = [makeChild(id: "c1"), makeChild(id: "c2")]
        let (sut, spy) = makeSUT(children: children)
        await sut.load(request: .init(familyId: "family-fa"))

        XCTAssertEqual(spy.lastLoad?.members.count, 2)
    }

    // MARK: - 3. load — childRepository fails → empty state, но present вызван

    func test_load_repositoryFails_emitsEmptyState() async {
        let (sut, spy) = makeSUT(children: [makeChild(id: "c1")], childRepoFails: true)
        await sut.load(request: .init(familyId: "family-fa"))

        XCTAssertTrue(spy.presentLoadCalled)
        XCTAssertTrue(spy.lastLoad?.members.isEmpty ?? false)
        XCTAssertEqual(spy.lastLoad?.streakState.totalMembers, 0)
    }

    // MARK: - 4. load — нет детей → streakState пустой

    func test_load_noChildren_zeroStreakState() async {
        let (sut, spy) = makeSUT(children: [])
        await sut.load(request: .init(familyId: "family-fa"))

        XCTAssertEqual(spy.lastLoad?.streakState.totalMembers, 0)
        XCTAssertFalse(spy.lastLoad?.streakState.allActiveToday ?? true)
    }

    // MARK: - 5. load — все дети активны сегодня → allActiveToday=true

    func test_load_allActiveToday_streakStateActive() async {
        let today = Calendar.current.startOfDay(for: Date())
        let children = [
            makeChild(id: "c1", streak: 5, lastSessionAt: today),
            makeChild(id: "c2", streak: 3, lastSessionAt: today)
        ]
        let (sut, spy) = makeSUT(children: children)
        await sut.load(request: .init(familyId: "family-fa"))

        XCTAssertEqual(spy.lastLoad?.streakState.allActiveToday, true)
        XCTAssertEqual(spy.lastLoad?.streakState.activeTodayCount, 2)
        // combinedDays = min streak среди детей при allActiveToday.
        XCTAssertEqual(spy.lastLoad?.streakState.combinedDays, 3)
    }

    // MARK: - 6. load — не все активны → combinedDays = 0

    func test_load_partialActive_combinedDaysZero() async {
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)
        let children = [
            makeChild(id: "c1", streak: 5, lastSessionAt: today),
            makeChild(id: "c2", streak: 3, lastSessionAt: yesterday)
        ]
        let (sut, spy) = makeSUT(children: children)
        await sut.load(request: .init(familyId: "family-fa"))

        XCTAssertEqual(spy.lastLoad?.streakState.combinedDays, 0)
        XCTAssertEqual(spy.lastLoad?.streakState.activeTodayCount, 1)
    }

    // MARK: - 7. load — sounds achievement: освоенные звуки агрегируются

    func test_load_masteredSoundsAggregated() async {
        let children = [
            makeChild(id: "c1", progressSummary: ["Р": 0.9, "С": 0.5]),
            makeChild(id: "c2", progressSummary: ["Ш": 0.95])
        ]
        let (sut, spy) = makeSUT(children: children)
        await sut.load(request: .init(familyId: "family-fa"))

        // progress для sounds achievement = кол-во звуков >= 0.85 у всех детей = 2 (Р, Ш).
        let soundsAch = FamilyAchievement.catalog.first { $0.category == .sounds }!
        XCTAssertEqual(spy.lastLoad?.progressById[soundsAch.id], 2)
    }

    // MARK: - 8. load — sessions achievement progress = суммарные сессии

    func test_load_sessionProgressFromRepository() async {
        let children = [makeChild(id: "c1")]
        let sessions = (0..<5).map { idx in
            TestDataBuilder.session(id: "s\(idx)", childId: "c1")
        }
        let (sut, spy) = makeSUT(children: children, sessions: sessions)
        await sut.load(request: .init(familyId: "family-fa"))

        let sessAch = FamilyAchievement.catalog.first { $0.category == .sessions }!
        XCTAssertEqual(spy.lastLoad?.progressById[sessAch.id], 5)
    }

    // MARK: - 9. load — bonus achievement: 2+ детей + есть сессия

    func test_load_bonusUnlocksWithTwoChildrenAndSession() async {
        let children = [makeChild(id: "c1"), makeChild(id: "c2")]
        let sessions = [TestDataBuilder.session(id: "s1", childId: "c1")]
        let (sut, spy) = makeSUT(children: children, sessions: sessions)
        await sut.load(request: .init(familyId: "family-fa"))

        let bonusAch = FamilyAchievement.catalog.first { $0.category == .bonus }!
        XCTAssertEqual(spy.lastLoad?.progressById[bonusAch.id], 1)
        XCTAssertTrue(spy.lastLoad?.unlockedIds.contains(bonusAch.id) ?? false)
    }

    // MARK: - 10. load — bonus не разблокирован с одним ребёнком

    func test_load_bonusLockedWithOneChild() async {
        let children = [makeChild(id: "c1")]
        let sessions = [TestDataBuilder.session(id: "s1", childId: "c1")]
        let (sut, spy) = makeSUT(children: children, sessions: sessions)
        await sut.load(request: .init(familyId: "family-fa"))

        let bonusAch = FamilyAchievement.catalog.first { $0.category == .bonus }!
        XCTAssertEqual(spy.lastLoad?.progressById[bonusAch.id], 0)
    }

    // MARK: - 11. recompute — без новых достижений → пустой delta

    func test_recompute_noNewUnlocks_emptyDelta() async {
        let (sut, spy) = makeSUT(children: [makeChild(id: "c1")])
        await sut.load(request: .init(familyId: "family-fa"))
        await sut.recompute(request: .init(familyId: "family-fa"))

        XCTAssertTrue(spy.presentRecomputeCalled)
        XCTAssertTrue(spy.lastRecompute?.newUnlockedIds.isEmpty ?? false)
    }

    // MARK: - 12. recompute — новое достижение → непустой delta

    func test_recompute_newUnlock_nonEmptyDelta() async {
        // Bonus achievement разблокируется только при 2+ детях и сессии.
        let children = [makeChild(id: "c1"), makeChild(id: "c2")]
        let sessions = [TestDataBuilder.session(id: "s1", childId: "c1")]
        let (sut, spy) = makeSUT(children: children, sessions: sessions)
        // Не вызываем load первым — recompute сам вызовет load и зафиксирует delta.
        await sut.recompute(request: .init(familyId: "family-fa"))

        let bonusAch = FamilyAchievement.catalog.first { $0.category == .bonus }!
        XCTAssertTrue(spy.lastRecompute?.newUnlockedIds.contains(bonusAch.id) ?? false)
    }

    // MARK: - 13. FamilyAchievement.find — по id

    func test_familyAchievement_find() {
        XCTAssertNotNil(FamilyAchievement.find(id: "fam.streak.7"))
        XCTAssertNil(FamilyAchievement.find(id: "nonexistent"))
    }

    // MARK: - 14. FamilyAchievement.symbolColor — по категории

    func test_familyAchievement_symbolColorByCategory() {
        let streakAch = FamilyAchievement.catalog.first { $0.category == .streak }!
        XCTAssertEqual(streakAch.symbolColor, "flame")
        let bonusAch = FamilyAchievement.catalog.first { $0.category == .bonus }!
        XCTAssertEqual(bonusAch.symbolColor, "gift")
    }

    // MARK: - 15. DataStore — familyId доступен

    func test_dataStore_familyIdSet() {
        let (sut, _) = makeSUT(children: [])
        XCTAssertEqual(sut.familyId, "family-fa")
    }
}
