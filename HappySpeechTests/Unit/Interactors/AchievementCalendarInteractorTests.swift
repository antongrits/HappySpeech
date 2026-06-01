@testable import HappySpeech
import XCTest

/// UTC-календарь для детерминированных дат в тестах (file-scope — нельзя
/// использовать `Self.` в default-аргументе из-за covariant Self).
private let achievementTestCalendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC") ?? .current
    return c
}()

// MARK: - AchievementCalendarInteractorTests
//
// AchievementCalendarInteractor — thin VIP (@Observable). Календарь строится из
// реальных сессий текущего месяца: достижение = сессия с точностью ≥ порога.
// Тесты покрывают: пустой старт, selectDay-toggle, selectedEntry и агрегацию.

@MainActor
final class AchievementCalendarInteractorTests: XCTestCase {

    private func makeSUT(
        childId: String = "child-1",
        sessions: [SessionDTO] = [],
        calendar: Calendar = achievementTestCalendar
    ) -> AchievementCalendarInteractor {
        AchievementCalendarInteractor(
            childId: childId,
            sessionRepository: MockSessionRepository(sessions: sessions),
            calendar: calendar
        )
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = AchievementCalendarInteractor(childId: "kid-cal")
        XCTAssertEqual(sut.childId, "kid-cal")
    }

    func test_initialState_isEmptyCurrentMonth() {
        let sut = AchievementCalendarInteractor(childId: "c")
        XCTAssertEqual(sut.state.totalAchievements, 0)
        XCTAssertFalse(sut.state.hasAnyAchievements)
        XCTAssertNil(sut.state.selectedDay)
    }

    func test_initialState_dayCountMatchesCurrentMonth() {
        let cal = achievementTestCalendar
        let expected = cal.range(of: .day, in: .month, for: Date())?.count ?? 30
        let sut = AchievementCalendarInteractor(childId: "c", calendar: cal)
        XCTAssertEqual(sut.state.days.count, expected)
    }

    func test_initialState_selectedEntryIsNil() {
        let sut = AchievementCalendarInteractor(childId: "c")
        XCTAssertNil(sut.selectedEntry)
    }

    // MARK: - selectDay

    func test_selectDay_setsSelectedDay() {
        let sut = AchievementCalendarInteractor(childId: "c")
        sut.selectDay(12)
        XCTAssertEqual(sut.state.selectedDay, 12)
    }

    func test_selectDay_sameDayTwice_deselects() {
        let sut = AchievementCalendarInteractor(childId: "c")
        sut.selectDay(7)
        sut.selectDay(7)
        XCTAssertNil(sut.state.selectedDay)
    }

    func test_selectDay_differentDay_switchesSelection() {
        let sut = AchievementCalendarInteractor(childId: "c")
        sut.selectDay(3)
        sut.selectDay(28)
        XCTAssertEqual(sut.state.selectedDay, 28)
    }

    func test_selectDay_outOfRange_selectedEntryIsNil() {
        let sut = AchievementCalendarInteractor(childId: "c")
        sut.selectDay(99)
        XCTAssertEqual(sut.state.selectedDay, 99)
        XCTAssertNil(sut.selectedEntry, "No DayEntry exists for day 99")
    }

    // MARK: - makeState aggregation

    func test_makeState_achievementOnHighAccuracyDay() {
        let cal = achievementTestCalendar
        let now = makeDate(year: 2026, month: 6, day: 15, cal: cal)
        let sessions = [
            session(date: now, sound: "Р", total: 10, correct: 9) // 90% ≥ 0.80
        ]
        let sut = makeSUT(sessions: sessions, calendar: cal)
        let state = sut.makeState(from: sessions, now: now)
        let entry = state.days.first { $0.day == 15 }
        XCTAssertEqual(entry?.achievementCount, 1)
        XCTAssertNotNil(entry?.topAchievement)
    }

    func test_makeState_noAchievementBelowThreshold() {
        let cal = achievementTestCalendar
        let now = makeDate(year: 2026, month: 6, day: 10, cal: cal)
        let sessions = [
            session(date: now, sound: "Ш", total: 10, correct: 5) // 50% < 0.80
        ]
        let sut = makeSUT(sessions: sessions, calendar: cal)
        let state = sut.makeState(from: sessions, now: now)
        let entry = state.days.first { $0.day == 10 }
        XCTAssertEqual(entry?.achievementCount, 0)
        XCTAssertNil(entry?.topAchievement)
    }

    func test_makeState_ignoresOtherMonths() {
        let cal = achievementTestCalendar
        let now = makeDate(year: 2026, month: 6, day: 15, cal: cal)
        let lastMonth = makeDate(year: 2026, month: 5, day: 15, cal: cal)
        let sessions = [session(date: lastMonth, sound: "Р", total: 10, correct: 10)]
        let sut = makeSUT(sessions: sessions, calendar: cal)
        let state = sut.makeState(from: sessions, now: now)
        XCTAssertEqual(state.totalAchievements, 0)
    }

    func test_makeState_topAchievement_includesSound() {
        let cal = achievementTestCalendar
        let now = makeDate(year: 2026, month: 6, day: 20, cal: cal)
        let sessions = [session(date: now, sound: "Л", total: 10, correct: 10)]
        let sut = makeSUT(sessions: sessions, calendar: cal)
        let entry = sut.makeState(from: sessions, now: now).days.first { $0.day == 20 }
        XCTAssertTrue(entry?.topAchievement?.contains("Л") ?? false)
    }

    func test_makeState_monthTitleIsRussian() {
        let cal = achievementTestCalendar
        let now = makeDate(year: 2026, month: 6, day: 1, cal: cal)
        let sut = makeSUT(calendar: cal)
        let state = sut.makeState(from: [], now: now)
        XCTAssertTrue(state.month.contains("2026"))
    }

    // MARK: - totalAchievements (model)

    func test_totalAchievements_sumsAllDayCounts() {
        let days = [
            AchievementCalendarModels.DayEntry(id: 1, day: 1, achievementCount: 2, topAchievement: nil),
            AchievementCalendarModels.DayEntry(id: 2, day: 2, achievementCount: 3, topAchievement: nil)
        ]
        let state = AchievementCalendarModels.ViewState(month: "X", days: days, selectedDay: nil)
        XCTAssertEqual(state.totalAchievements, 5)
        XCTAssertTrue(state.hasAnyAchievements)
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int, cal: Calendar) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 12
        return cal.date(from: comps) ?? Date()
    }

    private func session(date: Date, sound: String, total: Int, correct: Int) -> SessionDTO {
        SessionDTO(
            id: UUID().uuidString,
            childId: "child-1",
            date: date,
            templateType: TemplateType.repeatAfterModel.rawValue,
            targetSound: sound,
            stage: CorrectionStage.wordInit.rawValue,
            durationSeconds: 200,
            totalAttempts: total,
            correctAttempts: correct,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
    }
}
