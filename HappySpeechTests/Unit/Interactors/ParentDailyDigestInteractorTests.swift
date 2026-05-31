@testable import HappySpeech
import XCTest

// MARK: - ParentDailyDigestInteractorTests
//
// ParentDailyDigestInteractor (@Observable) exposes a daily digest (KPIs, a
// photo-moment and a tip). Without a SessionRepository it stays on the seed
// `.initial` state and refresh() is a safe no-op. With an injected repository it
// recomputes KPIs (minutes, accuracy, streak, sessions) from real session data —
// covered by the aggregation tests below via the pure makeState/activeDayStreak.

@MainActor
final class ParentDailyDigestInteractorTests: XCTestCase {

    private func makeSUT() -> ParentDailyDigestInteractor {
        ParentDailyDigestInteractor()
    }

    private func makeSession(
        daysAgo: Int,
        durationSeconds: Int = 480,
        totalAttempts: Int = 10,
        correctAttempts: Int = 8,
        calendar: Calendar = .current
    ) -> SessionDTO {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return SessionDTO(
            id: UUID().uuidString,
            childId: "child-1",
            date: date,
            templateType: "repeat-after-model",
            targetSound: "Р",
            stage: "word",
            durationSeconds: durationSeconds,
            totalAttempts: totalAttempts,
            correctAttempts: correctAttempts,
            fatigueDetected: false,
            isSynced: true,
            attempts: []
        )
    }

    // MARK: - Initial state

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_hasKPIs() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.kpis.isEmpty)
        XCTAssertEqual(Set(sut.state.kpis.map(\.id)).count, sut.state.kpis.count)
        for kpi in sut.state.kpis {
            XCTAssertFalse(kpi.icon.isEmpty)
            XCTAssertFalse(kpi.value.isEmpty)
            XCTAssertFalse(kpi.label.isEmpty)
        }
    }

    func test_initialState_photoMomentPopulated() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.photoMomentEmoji.isEmpty)
        XCTAssertFalse(sut.state.photoMomentCaption.isEmpty)
    }

    func test_initialState_tipPopulated() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.tip.text.isEmpty)
        XCTAssertFalse(sut.state.tip.author.isEmpty)
    }

    // MARK: - refresh (no repository → no-op)

    func test_refresh_withoutRepository_leavesStateUnchanged() {
        let sut = makeSUT()
        let before = sut.state
        sut.refresh()
        XCTAssertEqual(sut.state, before)
    }

    // MARK: - Aggregation (makeState)

    func test_makeState_todayMinutesSummed() {
        let sut = makeSUT()
        let sessions = [
            makeSession(daysAgo: 0, durationSeconds: 300),
            makeSession(daysAgo: 0, durationSeconds: 360)
        ]
        let state = sut.makeState(from: sessions)
        // 300 + 360 = 660s = 11 min.
        let minutesKPI = state.kpis.first { $0.id == "min" }
        XCTAssertEqual(minutesKPI?.value, "11 мин")
    }

    func test_makeState_accuracyPercent() {
        let sut = makeSUT()
        let sessions = [
            makeSession(daysAgo: 0, totalAttempts: 10, correctAttempts: 9)
        ]
        let state = sut.makeState(from: sessions)
        let scoreKPI = state.kpis.first { $0.id == "score" }
        XCTAssertEqual(scoreKPI?.value, "90%")
    }

    func test_makeState_ignoresOlderSessionsForTodayKPIs() {
        let sut = makeSUT()
        let sessions = [
            makeSession(daysAgo: 0, durationSeconds: 120, totalAttempts: 4, correctAttempts: 4),
            makeSession(daysAgo: 3, durationSeconds: 600, totalAttempts: 20, correctAttempts: 5)
        ]
        let state = sut.makeState(from: sessions)
        let minutesKPI = state.kpis.first { $0.id == "min" }
        let scoreKPI = state.kpis.first { $0.id == "score" }
        XCTAssertEqual(minutesKPI?.value, "2 мин")   // only today's 120s
        XCTAssertEqual(scoreKPI?.value, "100%")        // only today's 4/4
    }

    func test_makeState_noTodaySessions_zeroAccuracy() {
        let sut = makeSUT()
        let sessions = [makeSession(daysAgo: 5)]
        let state = sut.makeState(from: sessions)
        XCTAssertEqual(state.kpis.first { $0.id == "score" }?.value, "0%")
        XCTAssertEqual(state.kpis.first { $0.id == "sessions" }?.value, "0")
    }

    // MARK: - Streak

    func test_streak_consecutiveDaysEndingToday() {
        let sut = makeSUT()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sessions = [
            makeSession(daysAgo: 0),
            makeSession(daysAgo: 1),
            makeSession(daysAgo: 2)
        ]
        XCTAssertEqual(sut.activeDayStreak(in: sessions, today: today), 3)
    }

    func test_streak_brokenByGap() {
        let sut = makeSUT()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sessions = [
            makeSession(daysAgo: 0),
            makeSession(daysAgo: 1),
            makeSession(daysAgo: 3)   // gap at day 2
        ]
        XCTAssertEqual(sut.activeDayStreak(in: sessions, today: today), 2)
    }

    func test_streak_yesterdayTailCounts() {
        let sut = makeSUT()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // No session today, but yesterday + day before.
        let sessions = [
            makeSession(daysAgo: 1),
            makeSession(daysAgo: 2)
        ]
        XCTAssertEqual(sut.activeDayStreak(in: sessions, today: today), 2)
    }

    func test_streak_emptyIsZero() {
        let sut = makeSUT()
        let today = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(sut.activeDayStreak(in: [], today: today), 0)
    }

    func test_streak_staleSessionsAreZero() {
        let sut = makeSUT()
        let today = Calendar.current.startOfDay(for: Date())
        // Last activity 5 days ago → streak ending today/yesterday is 0.
        XCTAssertEqual(sut.activeDayStreak(in: [makeSession(daysAgo: 5)], today: today), 0)
    }

    // MARK: - refresh with repository

    func test_refresh_withRepository_recomputesKPIs() async {
        let repo = MockSessionRepository()
        repo.sessions = [
            makeSession(daysAgo: 0, durationSeconds: 600, totalAttempts: 10, correctAttempts: 7)
        ]
        let sut = ParentDailyDigestInteractor(sessionRepository: repo, childId: "child-1")
        sut.refresh()
        // refresh() spawns a Task; let it complete.
        try? await Task.sleep(nanoseconds: 200_000_000)
        let minutesKPI = sut.state.kpis.first { $0.id == "min" }
        XCTAssertEqual(minutesKPI?.value, "10 мин")
        XCTAssertEqual(sut.state.kpis.first { $0.id == "score" }?.value, "70%")
    }
}
