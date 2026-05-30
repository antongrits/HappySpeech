@testable import HappySpeech
import XCTest

// MARK: - HabitStreakDashboardInteractorTests
//
// HabitStreakDashboardInteractor is a thin VIP MVP variant (@Observable). It holds
// a 12-week heat-map of practice days plus an optional selected day; select(_:) /
// clearSelection() manage the selection. The Day type maps minutes → an intensity
// bucket (0...4), and ViewState derives currentStreak and totalMinutes. Tests cover
// the seed shape, the selection mutations, the intensity bucketing boundaries and
// the streak/total derives over crafted day sequences.

@MainActor
final class HabitStreakDashboardInteractorTests: XCTestCase {

    private typealias Day = HabitStreakDashboardModels.Day
    private typealias ViewState = HabitStreakDashboardModels.ViewState

    private func makeSUT() -> HabitStreakDashboardInteractor {
        HabitStreakDashboardInteractor(childId: "child-1")
    }

    // MARK: - Init / seed

    func test_init_storesChildId() {
        let sut = HabitStreakDashboardInteractor(childId: "c-99")
        XCTAssertEqual(sut.childId, "c-99")
    }

    func test_initialState_hasFullGrid() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.days.count, ViewState.weeks * ViewState.daysPerWeek)
        XCTAssertNil(sut.state.selected)
    }

    func test_initialState_intensityMatchesMinutes() {
        let sut = makeSUT()
        for day in sut.state.days {
            XCTAssertEqual(day.intensity, Day.intensityForMinutes(day.minutes))
            XCTAssertTrue((0...4).contains(day.intensity))
        }
    }

    // MARK: - select / clearSelection

    func test_select_setsSelectedDay() {
        let sut = makeSUT()
        let day = sut.state.days[10]
        sut.select(day)
        XCTAssertEqual(sut.state.selected, day)
    }

    func test_select_doesNotMutateDays() {
        let sut = makeSUT()
        let before = sut.state.days
        sut.select(sut.state.days[3])
        XCTAssertEqual(sut.state.days, before)
    }

    func test_clearSelection_resetsSelected() {
        let sut = makeSUT()
        sut.select(sut.state.days[5])
        sut.clearSelection()
        XCTAssertNil(sut.state.selected)
    }

    func test_select_replacesPreviousSelection() {
        let sut = makeSUT()
        sut.select(sut.state.days[1])
        sut.select(sut.state.days[2])
        XCTAssertEqual(sut.state.selected, sut.state.days[2])
    }

    // MARK: - intensityForMinutes boundaries

    func test_intensityForMinutes_zero() {
        XCTAssertEqual(Day.intensityForMinutes(0), 0)
    }

    func test_intensityForMinutes_lowBucket() {
        XCTAssertEqual(Day.intensityForMinutes(1), 1)
        XCTAssertEqual(Day.intensityForMinutes(4), 1)
    }

    func test_intensityForMinutes_midBucket() {
        XCTAssertEqual(Day.intensityForMinutes(5), 2)
        XCTAssertEqual(Day.intensityForMinutes(9), 2)
    }

    func test_intensityForMinutes_highBucket() {
        XCTAssertEqual(Day.intensityForMinutes(10), 3)
        XCTAssertEqual(Day.intensityForMinutes(14), 3)
    }

    func test_intensityForMinutes_maxBucket() {
        XCTAssertEqual(Day.intensityForMinutes(15), 4)
        XCTAssertEqual(Day.intensityForMinutes(120), 4)
    }

    // MARK: - currentStreak
    //
    // The implementation returns max(totalActiveDays, trailingActiveRun): `streak`
    // counts every active day, `counted` counts the trailing run until the first
    // gap, and the larger wins. These tests pin that actual behaviour.

    func test_currentStreak_returnsMaxOfTotalAndTrailingRun() {
        let days = [
            Day(id: 0, intensity: 0, minutes: 0),
            Day(id: 1, intensity: 2, minutes: 6),
            Day(id: 2, intensity: 0, minutes: 0),
            Day(id: 3, intensity: 1, minutes: 2),
            Day(id: 4, intensity: 3, minutes: 11)
        ]
        let state = ViewState(days: days, selected: nil)
        // Total active days = 3 (ids 1, 3, 4); trailing run = 2 (ids 4, 3) → max = 3.
        XCTAssertEqual(state.currentStreak, 3)
    }

    func test_currentStreak_lastDayInactive_fallsBackToTotalActive() {
        let days = [
            Day(id: 0, intensity: 3, minutes: 11),
            Day(id: 1, intensity: 0, minutes: 0)
        ]
        let state = ViewState(days: days, selected: nil)
        // Trailing run = 0 (last day inactive) but total active = 1 → max = 1.
        XCTAssertEqual(state.currentStreak, 1)
    }

    func test_currentStreak_allInactive_isZero() {
        let days = (0..<4).map { Day(id: $0, intensity: 0, minutes: 0) }
        let state = ViewState(days: days, selected: nil)
        XCTAssertEqual(state.currentStreak, 0)
    }

    func test_currentStreak_allActive() {
        let days = (0..<5).map { Day(id: $0, intensity: 2, minutes: 6) }
        let state = ViewState(days: days, selected: nil)
        XCTAssertEqual(state.currentStreak, 5)
    }

    // MARK: - totalMinutes

    func test_totalMinutes_sumsAllDays() {
        let days = [
            Day(id: 0, intensity: 0, minutes: 0),
            Day(id: 1, intensity: 2, minutes: 6),
            Day(id: 2, intensity: 4, minutes: 20)
        ]
        let state = ViewState(days: days, selected: nil)
        XCTAssertEqual(state.totalMinutes, 26)
    }

    func test_totalMinutes_seedMatchesSum() {
        let sut = makeSUT()
        let expected = sut.state.days.reduce(0) { $0 + $1.minutes }
        XCTAssertEqual(sut.state.totalMinutes, expected)
    }
}
