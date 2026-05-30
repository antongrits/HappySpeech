@testable import HappySpeech
import XCTest

// MARK: - AchievementCalendarInteractorTests
//
// AchievementCalendarInteractor is a thin VIP MVP variant (@Observable).
// selectDay() toggles the selected day (tapping the same day deselects);
// selectedEntry resolves the selection to a DayEntry; totalAchievements sums all
// day counts. Tests cover toggle selection, entry resolution and the total.

@MainActor
final class AchievementCalendarInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> AchievementCalendarInteractor {
        AchievementCalendarInteractor(childId: childId)
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-cal")
        XCTAssertEqual(sut.childId, "kid-cal")
    }

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_noSelectedDay() {
        let sut = makeSUT()
        XCTAssertNil(sut.state.selectedDay)
    }

    func test_initialState_thirtyDays() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.days.count, 30)
    }

    func test_initialState_selectedEntryIsNil() {
        let sut = makeSUT()
        XCTAssertNil(sut.selectedEntry)
    }

    // MARK: - totalAchievements

    func test_totalAchievements_sumsAllDayCounts() {
        let sut = makeSUT()
        // Seeded counts: 2 + 1 + 3 + 1 + 2 + 1 + 4 = 14
        XCTAssertEqual(sut.state.totalAchievements, 14)
    }

    func test_totalAchievements_matchesManualSum() {
        let sut = makeSUT()
        let manual = sut.state.days.reduce(0) { $0 + $1.achievementCount }
        XCTAssertEqual(sut.state.totalAchievements, manual)
    }

    // MARK: - selectDay

    func test_selectDay_setsSelectedDay() {
        let sut = makeSUT()
        sut.selectDay(12)
        XCTAssertEqual(sut.state.selectedDay, 12)
    }

    func test_selectDay_sameDayTwice_deselects() {
        let sut = makeSUT()
        sut.selectDay(7)
        sut.selectDay(7)
        XCTAssertNil(sut.state.selectedDay)
    }

    func test_selectDay_differentDay_switchesSelection() {
        let sut = makeSUT()
        sut.selectDay(3)
        sut.selectDay(28)
        XCTAssertEqual(sut.state.selectedDay, 28)
    }

    // MARK: - selectedEntry

    func test_selectedEntry_resolvesToMatchingDay() {
        let sut = makeSUT()
        sut.selectDay(12)
        XCTAssertEqual(sut.selectedEntry?.day, 12)
        XCTAssertEqual(sut.selectedEntry?.achievementCount, 3)
        XCTAssertEqual(sut.selectedEntry?.topAchievement, "Грамота-старт")
    }

    func test_selectedEntry_emptyDay_hasZeroCountAndNilTop() {
        let sut = makeSUT()
        sut.selectDay(1)   // day 1 falls in the default (empty) bucket
        XCTAssertEqual(sut.selectedEntry?.achievementCount, 0)
        XCTAssertNil(sut.selectedEntry?.topAchievement)
    }

    func test_selectedEntry_becomesNilAfterDeselect() {
        let sut = makeSUT()
        sut.selectDay(28)
        sut.selectDay(28)
        XCTAssertNil(sut.selectedEntry)
    }

    func test_selectDay_outOfRange_selectedEntryIsNil() {
        let sut = makeSUT()
        sut.selectDay(99)
        XCTAssertEqual(sut.state.selectedDay, 99)
        XCTAssertNil(sut.selectedEntry, "No DayEntry exists for day 99")
    }
}
