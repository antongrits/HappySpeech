@testable import HappySpeech
import XCTest

/// UTC-календарь для детерминированных дат (file-scope — нельзя `Self.` в
/// default-аргументе из-за covariant Self).
private let goalTrackerTestCalendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC") ?? .current
    return c
}()

// MARK: - GoalTrackerKidInteractorTests
//
// GoalTrackerKidInteractor — thin VIP (@Observable). Цели теперь считаются из
// реальных данных: минуты практики за сегодня, число разных звуков сегодня,
// серия активных дней. Тесты покрывают: нулевой старт, агрегацию из сессий,
// серию (из профиля и fallback по сессиям) и computed-прогресс.

@MainActor
final class GoalTrackerKidInteractorTests: XCTestCase {

    private typealias Kind = GoalTrackerKidModels.GoalKind

    private func makeSUT(
        childId: String = "child-1",
        sessions: [SessionDTO] = [],
        child: ChildProfileDTO? = nil,
        calendar: Calendar = goalTrackerTestCalendar
    ) -> GoalTrackerKidInteractor {
        let sessionRepo = MockSessionRepository(sessions: sessions)
        let childRepo = child.map { MockChildRepository(children: [$0]) }
        return GoalTrackerKidInteractor(
            childId: childId,
            sessionRepository: sessionRepo,
            childRepository: childRepo,
            calendar: calendar
        )
    }

    // MARK: - Init / initial state

    func test_init_storesChildId() {
        let sut = GoalTrackerKidInteractor(childId: "kid-42")
        XCTAssertEqual(sut.childId, "kid-42")
    }

    func test_initialState_matchesInitialViewState() {
        let sut = GoalTrackerKidInteractor(childId: "c")
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_allZeros() {
        let sut = GoalTrackerKidInteractor(childId: "c")
        XCTAssertTrue(sut.state.goals.allSatisfy { $0.current == 0 })
    }

    func test_initialState_hasAllGoalKinds() {
        let sut = GoalTrackerKidInteractor(childId: "c")
        let kinds = Set(sut.state.goals.map(\.id))
        XCTAssertEqual(kinds, Set(Kind.allCases))
    }

    // MARK: - reset

    func test_reset_restoresInitialState() {
        let sut = GoalTrackerKidInteractor(childId: "c")
        sut.reset()
        XCTAssertEqual(sut.state, .initial)
    }

    // MARK: - makeState aggregation

    func test_makeState_minutesToday_sumsTodaySessionsOnly() {
        let cal = goalTrackerTestCalendar
        let today = cal.startOfDay(for: Date())
        let sessions = [
            session(date: today.addingTimeInterval(3600), seconds: 300, sound: "Р"),          // 5 мин сегодня
            session(date: today.addingTimeInterval(7200), seconds: 180, sound: "Р"),          // 3 мин сегодня
            session(date: today.addingTimeInterval(-2 * 86400), seconds: 600, sound: "С")     // не сегодня
        ]
        let sut = makeSUT(sessions: sessions, calendar: cal)
        let state = sut.makeState(from: sessions, streak: 0)
        let minutes = state.goals.first { $0.id == .minutesToday }?.current
        XCTAssertEqual(minutes, 8) // 5 + 3
    }

    func test_makeState_newSounds_countsDistinctTodaySounds() {
        let cal = goalTrackerTestCalendar
        let today = cal.startOfDay(for: Date())
        let sessions = [
            session(date: today.addingTimeInterval(3600), seconds: 120, sound: "Р"),
            session(date: today.addingTimeInterval(4000), seconds: 120, sound: "Р"),   // дубль звука
            session(date: today.addingTimeInterval(5000), seconds: 120, sound: "Ш")
        ]
        let sut = makeSUT(sessions: sessions, calendar: cal)
        let state = sut.makeState(from: sessions, streak: 0)
        let sounds = state.goals.first { $0.id == .newSounds }?.current
        XCTAssertEqual(sounds, 2) // Р, Ш
    }

    func test_makeState_streak_passedThrough() {
        let sut = makeSUT()
        let state = sut.makeState(from: [], streak: 4)
        XCTAssertEqual(state.goals.first { $0.id == .streakDays }?.current, 4)
    }

    func test_makeState_targetsAreMethodicalDefaults() {
        let sut = makeSUT()
        let state = sut.makeState(from: [], streak: 0)
        XCTAssertEqual(state.goals.first { $0.id == .minutesToday }?.target, 10)
        XCTAssertEqual(state.goals.first { $0.id == .newSounds }?.target, 3)
        XCTAssertEqual(state.goals.first { $0.id == .streakDays }?.target, 7)
    }

    // MARK: - activeDayStreak fallback

    func test_activeDayStreak_todayOnly_isOne() {
        let cal = goalTrackerTestCalendar
        let today = cal.startOfDay(for: Date())
        let sut = makeSUT(calendar: cal)
        let streak = sut.activeDayStreak(in: [session(date: today, seconds: 60, sound: "Р")])
        XCTAssertEqual(streak, 1)
    }

    func test_activeDayStreak_threeConsecutiveDays_isThree() {
        let cal = goalTrackerTestCalendar
        let today = cal.startOfDay(for: Date())
        let days = [0, 1, 2].map { offset in
            session(date: cal.date(byAdding: .day, value: -offset, to: today)!, seconds: 60, sound: "Р")
        }
        let sut = makeSUT(calendar: cal)
        XCTAssertEqual(sut.activeDayStreak(in: days), 3)
    }

    func test_activeDayStreak_gapBreaksStreak() {
        let cal = goalTrackerTestCalendar
        let today = cal.startOfDay(for: Date())
        let days = [0, 2, 3].map { offset in
            session(date: cal.date(byAdding: .day, value: -offset, to: today)!, seconds: 60, sound: "Р")
        }
        let sut = makeSUT(calendar: cal)
        // Сегодня активен, вчера (1) пусто → серия = 1.
        XCTAssertEqual(sut.activeDayStreak(in: days), 1)
    }

    func test_activeDayStreak_empty_isZero() {
        let sut = makeSUT()
        XCTAssertEqual(sut.activeDayStreak(in: []), 0)
    }

    // MARK: - progress computations (model)

    func test_goalProgress_isFractionOfTarget() {
        let goal = GoalTrackerKidModels.Goal(id: .minutesToday, current: 6, target: 10)
        XCTAssertEqual(goal.progress, 0.6, accuracy: 0.0001)
    }

    func test_goalProgress_zeroTarget_isZero() {
        let goal = GoalTrackerKidModels.Goal(id: .streakDays, current: 5, target: 0)
        XCTAssertEqual(goal.progress, 0)
    }

    func test_goalProgress_clampedAtOne() {
        let goal = GoalTrackerKidModels.Goal(id: .minutesToday, current: 50, target: 10)
        XCTAssertEqual(goal.progress, 1.0, accuracy: 0.0001)
        XCTAssertTrue(goal.isReached)
    }

    func test_overallProgress_isAverageOfGoalProgress() {
        let state = GoalTrackerKidModels.ViewState(goals: [
            .init(id: .minutesToday, current: 5, target: 10),  // 0.5
            .init(id: .newSounds, current: 3, target: 3),       // 1.0
            .init(id: .streakDays, current: 0, target: 7)       // 0.0
        ])
        XCTAssertEqual(state.overallProgress, 0.5, accuracy: 0.0001)
    }

    func test_overallProgress_emptyGoals_isZero() {
        let state = GoalTrackerKidModels.ViewState(goals: [])
        XCTAssertEqual(state.overallProgress, 0)
    }

    // MARK: - Helpers

    private func session(date: Date, seconds: Int, sound: String) -> SessionDTO {
        SessionDTO(
            id: UUID().uuidString,
            childId: "child-1",
            date: date,
            templateType: TemplateType.repeatAfterModel.rawValue,
            targetSound: sound,
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
