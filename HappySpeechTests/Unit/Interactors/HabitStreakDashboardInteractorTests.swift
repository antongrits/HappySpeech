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
    // currentStreak — это ТОЛЬКО непрерывная trailing-серия (подряд идущие активные
    // дни, заканчивающиеся сегодня или вчера). `days` отсортирован по возрастанию,
    // последний элемент — сегодня. Разрыв в середине обрывает серию; если сегодня
    // неактивен, но вчера был — серия продолжается до вчера. Это консистентно с
    // методикой daily-streak (SessionComplete / StutteringInteractor).

    func test_currentStreak_gapInMiddle_countsOnlyTrailingRun() {
        let days = [
            Day(id: 0, intensity: 0, minutes: 0),
            Day(id: 1, intensity: 2, minutes: 6),
            Day(id: 2, intensity: 0, minutes: 0),   // разрыв
            Day(id: 3, intensity: 1, minutes: 2),
            Day(id: 4, intensity: 3, minutes: 11)    // сегодня
        ]
        let state = ViewState(days: days, selected: nil)
        // Trailing run от сегодня: ids 4, 3 активны, id 2 — разрыв → серия = 2.
        XCTAssertEqual(state.currentStreak, 2)
    }

    func test_currentStreak_onlyToday_isOne() {
        let days = [
            Day(id: 0, intensity: 0, minutes: 0),
            Day(id: 1, intensity: 0, minutes: 0),
            Day(id: 2, intensity: 3, minutes: 11)    // сегодня активен
        ]
        let state = ViewState(days: days, selected: nil)
        XCTAssertEqual(state.currentStreak, 1)
    }

    func test_currentStreak_yesterdayAndToday_isTwo() {
        let days = [
            Day(id: 0, intensity: 0, minutes: 0),
            Day(id: 1, intensity: 2, minutes: 6),    // вчера
            Day(id: 2, intensity: 3, minutes: 11)    // сегодня
        ]
        let state = ViewState(days: days, selected: nil)
        XCTAssertEqual(state.currentStreak, 2)
    }

    func test_currentStreak_todayInactiveYesterdayActive_continuesToYesterday() {
        let days = [
            Day(id: 0, intensity: 1, minutes: 2),    // позавчера
            Day(id: 1, intensity: 2, minutes: 6),    // вчера
            Day(id: 2, intensity: 0, minutes: 0)     // сегодня неактивен
        ]
        let state = ViewState(days: days, selected: nil)
        // Сегодня неактивен, но вчера был → серия продолжается до вчера = 2.
        XCTAssertEqual(state.currentStreak, 2)
    }

    func test_currentStreak_todayAndYesterdayInactive_isZero() {
        let days = [
            Day(id: 0, intensity: 3, minutes: 11),   // позавчера активен
            Day(id: 1, intensity: 0, minutes: 0),    // вчера неактивен
            Day(id: 2, intensity: 0, minutes: 0)     // сегодня неактивен
        ]
        let state = ViewState(days: days, selected: nil)
        // Ни сегодня, ни вчера — серия прервана.
        XCTAssertEqual(state.currentStreak, 0)
    }

    func test_currentStreak_emptyDays_isZero() {
        let state = ViewState(days: [], selected: nil)
        XCTAssertEqual(state.currentStreak, 0)
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

    // MARK: - empty / make factories

    func test_emptyState_allZeroMinutes() {
        let state = ViewState.empty
        XCTAssertEqual(state.days.count, ViewState.totalCells)
        XCTAssertTrue(state.days.allSatisfy { $0.minutes == 0 && $0.intensity == 0 })
        XCTAssertEqual(state.totalMinutes, 0)
    }

    func test_make_placesMinutesAtOffsets() {
        let last = ViewState.totalCells - 1
        let state = ViewState.make(minutesByOffset: [last: 12, last - 1: 6])
        XCTAssertEqual(state.days[last].minutes, 12)
        XCTAssertEqual(state.days[last].intensity, Day.intensityForMinutes(12))
        XCTAssertEqual(state.days[last - 1].minutes, 6)
    }

    func test_make_missingOffsetsAreZero() {
        let state = ViewState.make(minutesByOffset: [:])
        XCTAssertTrue(state.days.allSatisfy { $0.minutes == 0 })
    }

    // MARK: - makeState aggregation from sessions

    func test_makeState_todaySessionLandsOnLastCell() {
        let cal = utcCalendar
        let today = cal.startOfDay(for: Date())
        let sut = HabitStreakDashboardInteractor(
            childId: "c",
            sessionRepository: MockSessionRepository(sessions: []),
            calendar: cal
        )
        let sessions = [session(date: today.addingTimeInterval(3600), seconds: 600)] // 10 мин
        let state = sut.makeState(from: sessions)
        XCTAssertEqual(state.days[ViewState.totalCells - 1].minutes, 10)
    }

    func test_makeState_yesterdaySessionLandsOnPenultimateCell() {
        let cal = utcCalendar
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let sut = HabitStreakDashboardInteractor(
            childId: "c",
            sessionRepository: MockSessionRepository(sessions: []),
            calendar: cal
        )
        let sessions = [session(date: yesterday.addingTimeInterval(3600), seconds: 300)] // 5 мин
        let state = sut.makeState(from: sessions)
        XCTAssertEqual(state.days[ViewState.totalCells - 2].minutes, 5)
    }

    func test_makeState_aggregatesMultipleSessionsSameDay() {
        let cal = utcCalendar
        let today = cal.startOfDay(for: Date())
        let sut = HabitStreakDashboardInteractor(
            childId: "c",
            sessionRepository: MockSessionRepository(sessions: []),
            calendar: cal
        )
        let sessions = [
            session(date: today.addingTimeInterval(1000), seconds: 300), // 5
            session(date: today.addingTimeInterval(5000), seconds: 180)  // 3
        ]
        let state = sut.makeState(from: sessions)
        XCTAssertEqual(state.days[ViewState.totalCells - 1].minutes, 8)
    }

    func test_makeState_dropsSessionsOlderThanWindow() {
        let cal = utcCalendar
        let today = cal.startOfDay(for: Date())
        let old = cal.date(byAdding: .day, value: -(ViewState.totalCells + 5), to: today)!
        let sut = HabitStreakDashboardInteractor(
            childId: "c",
            sessionRepository: MockSessionRepository(sessions: []),
            calendar: cal
        )
        let state = sut.makeState(from: [session(date: old, seconds: 600)])
        XCTAssertEqual(state.totalMinutes, 0)
    }

    // MARK: - Helpers

    private var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC") ?? .current
        return c
    }

    private func session(date: Date, seconds: Int) -> SessionDTO {
        SessionDTO(
            id: UUID().uuidString,
            childId: "c",
            date: date,
            templateType: TemplateType.repeatAfterModel.rawValue,
            targetSound: "Р",
            stage: CorrectionStage.wordInit.rawValue,
            durationSeconds: seconds,
            totalAttempts: 5,
            correctAttempts: 4,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
    }
}
