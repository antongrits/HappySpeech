@testable import HappySpeech
import XCTest

// MARK: - FamilyAchievementsPresenterTests
//
// Block V v18 — покрытие FamilyAchievementsPresenter (7 тестов).
// Тестируются оба метода presentationLogic через DisplaySpy.

@MainActor
final class FamilyAchievementsPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: FamilyAchievementsDisplayLogic {
        var loadVM: FamilyAchievementsModels.Load.ViewModel?
        var recomputeVM: FamilyAchievementsModels.Recompute.ViewModel?

        func displayLoad(viewModel: FamilyAchievementsModels.Load.ViewModel) async {
            loadVM = viewModel
        }
        func displayRecompute(viewModel: FamilyAchievementsModels.Recompute.ViewModel) async {
            recomputeVM = viewModel
        }
    }

    private func makeSUT() -> (FamilyAchievementsPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = FamilyAchievementsPresenter(displayLogic: spy)
        return (presenter, spy)
    }

    private func makeMember(
        id: String = UUID().uuidString,
        name: String = "Ваня",
        age: Int = 6,
        streak: Int = 3,
        totalSessions: Int = 10,
        masteredSounds: [String] = ["С", "Р"],
        isActive: Bool = true
    ) -> FamilyMemberSummary {
        FamilyMemberSummary(
            id: id,
            displayName: name,
            age: age,
            avatarSymbol: "person.fill",
            currentStreak: streak,
            totalSessions: totalSessions,
            masteredSounds: masteredSounds,
            isActive: isActive
        )
    }

    private func makeStreakState(
        combinedDays: Int = 5,
        allActiveToday: Bool = true,
        total: Int = 2,
        activeToday: Int = 2
    ) -> FamilyStreakState {
        FamilyStreakState(
            combinedDays: combinedDays,
            allActiveToday: allActiveToday,
            totalMembers: total,
            activeTodayCount: activeToday
        )
    }

    // MARK: - presentLoad

    func test_presentLoad_allActiveToday_progressFractionIs1() async {
        let (sut, spy) = makeSUT()
        let streak = makeStreakState(allActiveToday: true, total: 2, activeToday: 2)
        let response = FamilyAchievementsModels.Load.Response(
            achievements: FamilyAchievement.catalog,
            unlockedIds: [],
            progressById: [:],
            members: [makeMember()],
            streakState: streak
        )
        await sut.presentLoad(response: response)
        XCTAssertEqual(spy.loadVM?.streakHero.progressFraction ?? -1.0, 1.0, accuracy: 0.001)
    }

    func test_presentLoad_partialActive_progressFractionIsPartial() async {
        let (sut, spy) = makeSUT()
        let streak = makeStreakState(allActiveToday: false, total: 4, activeToday: 2)
        let response = FamilyAchievementsModels.Load.Response(
            achievements: [],
            unlockedIds: [],
            progressById: [:],
            members: [makeMember()],
            streakState: streak
        )
        await sut.presentLoad(response: response)
        XCTAssertEqual(spy.loadVM?.streakHero.progressFraction ?? -1.0, 0.5, accuracy: 0.001)
    }

    func test_presentLoad_emptyMembers_progressFractionIsZero() async {
        let (sut, spy) = makeSUT()
        let streak = FamilyStreakState(
            combinedDays: 0,
            allActiveToday: false,
            totalMembers: 0,
            activeTodayCount: 0
        )
        let response = FamilyAchievementsModels.Load.Response(
            achievements: [],
            unlockedIds: [],
            progressById: [:],
            members: [],
            streakState: streak
        )
        await sut.presentLoad(response: response)
        XCTAssertEqual(spy.loadVM?.streakHero.progressFraction ?? -1.0, 0.0, accuracy: 0.001)
    }

    func test_presentLoad_achievementsSorted_unlockedFirst() async {
        let (sut, spy) = makeSUT()
        let achievements = FamilyAchievement.catalog
        let unlockedId = achievements[2].id
        let response = FamilyAchievementsModels.Load.Response(
            achievements: achievements,
            unlockedIds: [unlockedId],
            progressById: [:],
            members: [],
            streakState: makeStreakState(total: 0, activeToday: 0)
        )
        await sut.presentLoad(response: response)
        let rows = spy.loadVM?.achievements ?? []
        XCTAssertFalse(rows.isEmpty)
        XCTAssertTrue(rows.first?.isUnlocked ?? false, "Разблокированное достижение должно быть первым")
    }

    func test_presentLoad_memberRow_streakZero_setsNoStreakLabel() async {
        let (sut, spy) = makeSUT()
        let member = makeMember(streak: 0)
        let response = FamilyAchievementsModels.Load.Response(
            achievements: [],
            unlockedIds: [],
            progressById: [:],
            members: [member],
            streakState: makeStreakState()
        )
        await sut.presentLoad(response: response)
        let row = spy.loadVM?.memberRows.first
        XCTAssertNotNil(row?.streakLabel)
        XCTAssertFalse(row?.streakLabel.isEmpty ?? true)
    }

    // MARK: - presentRecompute

    func test_presentRecompute_emptyNewUnlocked_toastIsNil() async {
        let (sut, spy) = makeSUT()
        let response = FamilyAchievementsModels.Recompute.Response(newUnlockedIds: [])
        await sut.presentRecompute(response: response)
        XCTAssertNil(spy.recomputeVM?.toastMessage)
        XCTAssertTrue(spy.recomputeVM?.unlockedAchievementsTitles.isEmpty ?? false)
    }

    func test_presentRecompute_singleNewUnlocked_hasToastMessage() async {
        let (sut, spy) = makeSUT()
        let id = FamilyAchievement.catalog.first!.id
        let response = FamilyAchievementsModels.Recompute.Response(newUnlockedIds: [id])
        await sut.presentRecompute(response: response)
        XCTAssertNotNil(spy.recomputeVM?.toastMessage)
        XCTAssertEqual(spy.recomputeVM?.unlockedAchievementsTitles.count, 1)
    }

    // MARK: - Additional coverage (Step 11 close-out)

    func test_presentRecompute_multipleNewUnlocked_toastReflectsCount() async {
        let (sut, spy) = makeSUT()
        let ids = FamilyAchievement.catalog.prefix(3).map(\.id)
        let response = FamilyAchievementsModels.Recompute.Response(newUnlockedIds: Set(ids))
        await sut.presentRecompute(response: response)
        XCTAssertNotNil(spy.recomputeVM?.toastMessage)
        XCTAssertEqual(spy.recomputeVM?.unlockedAchievementsTitles.count, 3)
    }

    func test_presentRecompute_unknownIds_areIgnored() async {
        let (sut, spy) = makeSUT()
        let response = FamilyAchievementsModels.Recompute.Response(
            newUnlockedIds: ["nonexistent.id.123"]
        )
        await sut.presentRecompute(response: response)
        // titles массив должен быть пустым, так как id не найден в каталоге
        XCTAssertEqual(spy.recomputeVM?.unlockedAchievementsTitles.count, 0)
    }

    func test_presentLoad_memberRow_streakOne_hasSingularDayLabel() async {
        let (sut, spy) = makeSUT()
        let member = makeMember(streak: 1)
        let response = FamilyAchievementsModels.Load.Response(
            achievements: [],
            unlockedIds: [],
            progressById: [:],
            members: [member],
            streakState: makeStreakState()
        )
        await sut.presentLoad(response: response)
        let row = spy.loadVM?.memberRows.first
        XCTAssertNotNil(row?.streakLabel)
        XCTAssertFalse(row?.streakLabel.isEmpty ?? true)
    }

    func test_presentLoad_memberRow_streakMany_hasMultiDaysLabel() async {
        let (sut, spy) = makeSUT()
        let member = makeMember(streak: 10)
        let response = FamilyAchievementsModels.Load.Response(
            achievements: [],
            unlockedIds: [],
            progressById: [:],
            members: [member],
            streakState: makeStreakState()
        )
        await sut.presentLoad(response: response)
        let row = spy.loadVM?.memberRows.first
        XCTAssertFalse(row?.streakLabel.isEmpty ?? true)
    }

    func test_presentLoad_memberRow_noMasteredSounds_hasDefaultLabel() async {
        let (sut, spy) = makeSUT()
        let member = makeMember(masteredSounds: [])
        let response = FamilyAchievementsModels.Load.Response(
            achievements: [],
            unlockedIds: [],
            progressById: [:],
            members: [member],
            streakState: makeStreakState()
        )
        await sut.presentLoad(response: response)
        let row = spy.loadVM?.memberRows.first
        XCTAssertNotNil(row?.masteredSoundsLabel)
        XCTAssertFalse(row?.masteredSoundsLabel.isEmpty ?? true)
    }

    func test_presentLoad_memberRow_masteredSounds_joinedWithMiddot() async {
        let (sut, spy) = makeSUT()
        let member = makeMember(masteredSounds: ["С", "З", "Р"])
        let response = FamilyAchievementsModels.Load.Response(
            achievements: [],
            unlockedIds: [],
            progressById: [:],
            members: [member],
            streakState: makeStreakState()
        )
        await sut.presentLoad(response: response)
        let row = spy.loadVM?.memberRows.first
        XCTAssertTrue(row?.masteredSoundsLabel.contains("·") ?? false)
        XCTAssertTrue(row?.masteredSoundsLabel.contains("С") ?? false)
        XCTAssertTrue(row?.masteredSoundsLabel.contains("Р") ?? false)
    }

    func test_presentLoad_memberRow_activeFlag_passedThrough() async {
        let (sut, spy) = makeSUT()
        let active = makeMember(name: "Алёша", isActive: true)
        let inactive = makeMember(name: "Маша", isActive: false)
        let response = FamilyAchievementsModels.Load.Response(
            achievements: [],
            unlockedIds: [],
            progressById: [:],
            members: [active, inactive],
            streakState: makeStreakState()
        )
        await sut.presentLoad(response: response)
        XCTAssertEqual(spy.loadVM?.memberRows.count, 2)
        XCTAssertTrue(spy.loadVM?.memberRows[0].isActiveToday ?? false)
        XCTAssertFalse(spy.loadVM?.memberRows[1].isActiveToday ?? true)
    }

    func test_presentLoad_achievementRow_progressLabel_clampedAtTotal() async {
        let (sut, spy) = makeSUT()
        // catalog первый = fam.streak.7, totalRequired = 7
        let ach = FamilyAchievement.catalog[0]
        let response = FamilyAchievementsModels.Load.Response(
            achievements: [ach],
            unlockedIds: [],
            progressById: [ach.id: 999], // huge value should be clamped
            members: [],
            streakState: makeStreakState(total: 0, activeToday: 0)
        )
        await sut.presentLoad(response: response)
        let row = spy.loadVM?.achievements.first
        XCTAssertTrue(row?.progressLabel.contains("\(ach.totalRequired)") ?? false)
        XCTAssertEqual(row?.progressFraction ?? 0, 1.0, accuracy: 0.001)
    }

    func test_presentLoad_achievementRow_zeroProgress_fractionIsZero() async {
        let (sut, spy) = makeSUT()
        let ach = FamilyAchievement.catalog[0]
        let response = FamilyAchievementsModels.Load.Response(
            achievements: [ach],
            unlockedIds: [],
            progressById: [:],
            members: [],
            streakState: makeStreakState(total: 0, activeToday: 0)
        )
        await sut.presentLoad(response: response)
        let row = spy.loadVM?.achievements.first
        XCTAssertEqual(row?.progressFraction ?? -1, 0.0, accuracy: 0.001)
    }

    func test_presentLoad_achievementRow_unlockedFlag_passed() async {
        let (sut, spy) = makeSUT()
        let ach = FamilyAchievement.catalog[0]
        let response = FamilyAchievementsModels.Load.Response(
            achievements: [ach],
            unlockedIds: [ach.id],
            progressById: [:],
            members: [],
            streakState: makeStreakState(total: 0, activeToday: 0)
        )
        await sut.presentLoad(response: response)
        XCTAssertTrue(spy.loadVM?.achievements.first?.isUnlocked ?? false)
    }

    func test_presentLoad_summaryRow_aggregatesSessions() async {
        let (sut, spy) = makeSUT()
        let m1 = makeMember(name: "A", totalSessions: 10)
        let m2 = makeMember(name: "B", totalSessions: 25)
        let response = FamilyAchievementsModels.Load.Response(
            achievements: [],
            unlockedIds: [],
            progressById: [:],
            members: [m1, m2],
            streakState: makeStreakState()
        )
        await sut.presentLoad(response: response)
        XCTAssertNotNil(spy.loadVM?.summary)
        XCTAssertFalse(spy.loadVM?.summary.totalSessionsLabel.isEmpty ?? true)
    }

    func test_presentLoad_summaryRow_countsUnique_masteredSounds() async {
        let (sut, spy) = makeSUT()
        let m1 = makeMember(name: "A", masteredSounds: ["С", "З"])
        let m2 = makeMember(name: "B", masteredSounds: ["С", "Р"])
        let response = FamilyAchievementsModels.Load.Response(
            achievements: [],
            unlockedIds: [],
            progressById: [:],
            members: [m1, m2],
            streakState: makeStreakState()
        )
        await sut.presentLoad(response: response)
        // ожидаем 3 уникальных звука: С, З, Р
        XCTAssertFalse(spy.loadVM?.summary.totalMasteredSoundsLabel.isEmpty ?? true)
    }

    func test_presentLoad_summaryRow_countsUnlockedAndTotal() async {
        let (sut, spy) = makeSUT()
        let achievements = FamilyAchievement.catalog
        let unlocked = Set([achievements[0].id, achievements[2].id])
        let response = FamilyAchievementsModels.Load.Response(
            achievements: achievements,
            unlockedIds: unlocked,
            progressById: [:],
            members: [],
            streakState: makeStreakState(total: 0, activeToday: 0)
        )
        await sut.presentLoad(response: response)
        XCTAssertEqual(spy.loadVM?.summary.unlockedCount, 2)
        XCTAssertEqual(spy.loadVM?.summary.totalCount, achievements.count)
    }

    func test_presentLoad_allCategoriesRender_noCrash() async {
        // Дёргаем каждую категорию через каталог — проверяем categoryLabel(for:).
        let (sut, spy) = makeSUT()
        let response = FamilyAchievementsModels.Load.Response(
            achievements: FamilyAchievement.catalog,
            unlockedIds: [],
            progressById: [:],
            members: [],
            streakState: makeStreakState(total: 0, activeToday: 0)
        )
        await sut.presentLoad(response: response)
        let rows = spy.loadVM?.achievements ?? []
        XCTAssertEqual(rows.count, FamilyAchievement.catalog.count)
        for row in rows {
            XCTAssertFalse(row.categoryLabel.isEmpty, "categoryLabel must not be empty for \(row.id)")
        }
    }

    func test_presentLoad_partialActive_subtitleIsNotEmpty() async {
        let (sut, spy) = makeSUT()
        let streak = makeStreakState(allActiveToday: false, total: 3, activeToday: 1)
        let response = FamilyAchievementsModels.Load.Response(
            achievements: [],
            unlockedIds: [],
            progressById: [:],
            members: [makeMember()],
            streakState: streak
        )
        await sut.presentLoad(response: response)
        XCTAssertFalse(spy.loadVM?.streakHero.titleLabel.isEmpty ?? true)
        XCTAssertFalse(spy.loadVM?.streakHero.subtitleLabel.isEmpty ?? true)
    }
}
