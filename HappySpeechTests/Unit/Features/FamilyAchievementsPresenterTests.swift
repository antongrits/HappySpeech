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
        XCTAssertEqual(spy.loadVM?.streakHero.progressFraction, 1.0, accuracy: 0.001)
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
        XCTAssertEqual(spy.loadVM?.streakHero.progressFraction, 0.5, accuracy: 0.001)
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
        XCTAssertEqual(spy.loadVM?.streakHero.progressFraction, 0.0, accuracy: 0.001)
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
}
