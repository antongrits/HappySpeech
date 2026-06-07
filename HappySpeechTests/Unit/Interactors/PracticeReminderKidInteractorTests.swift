@testable import HappySpeech
import XCTest

// MARK: - PracticeReminderKidInteractorTests
//
// PracticeReminderKidInteractor reads REAL data: minutes practiced today (sum of
// today's session durations) and the current active-day streak (profile →
// fallback over sessions). `.initial` is neutral (0/0 + loading) — no fabricated
// "5 min / streak 4". Tests use mock repositories.

@MainActor
final class PracticeReminderKidInteractorTests: XCTestCase {

    private let calendar = Calendar.current

    private func session(
        id: String,
        daysAgo: Int,
        durationSeconds: Int,
        childId: String = "child-1"
    ) -> SessionDTO {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return SessionDTO(
            id: id,
            childId: childId,
            date: date,
            templateType: "repeat-after-model",
            targetSound: "Р",
            stage: "word",
            durationSeconds: durationSeconds,
            totalAttempts: 5,
            correctAttempts: 4,
            fatigueDetected: false,
            isSynced: true,
            attempts: []
        )
    }

    private func makeSUT(
        childId: String = "child-1",
        sessions: [SessionDTO] = [],
        profileStreak: Int? = nil
    ) -> PracticeReminderKidInteractor {
        let sessionRepo = MockSessionRepository(sessions: sessions)
        var childRepo: MockChildRepository?
        if let profileStreak {
            childRepo = MockChildRepository(children: [
                ChildProfileDTO(
                    id: childId, name: "Test", age: 6, targetSounds: ["Р"],
                    parentId: "p", currentStreak: profileStreak
                )
            ])
        }
        return PracticeReminderKidInteractor(
            childId: childId,
            sessionRepository: sessionRepo,
            childRepository: childRepo
        )
    }

    // MARK: - Initial state (no fabrication)

    func test_init_storesChildId() {
        let sut = PracticeReminderKidInteractor(childId: "kid-9")
        XCTAssertEqual(sut.childId, "kid-9")
    }

    func test_initialState_isZeroAndLoading() {
        let sut = PracticeReminderKidInteractor(childId: "kid-9")
        XCTAssertEqual(sut.state.minutesToday, 0)
        XCTAssertEqual(sut.state.streakDays, 0)
        XCTAssertTrue(sut.state.isLoading)
        XCTAssertFalse(sut.state.isDismissed)
    }

    func test_load_noRepository_staysZero() async {
        let sut = PracticeReminderKidInteractor(childId: "kid-9")
        await sut.load()
        XCTAssertEqual(sut.state.minutesToday, 0)
        XCTAssertEqual(sut.state.streakDays, 0)
        XCTAssertFalse(sut.state.isLoading)
    }

    // MARK: - Real minutes today

    func test_load_sumsTodayMinutes() async {
        let sut = makeSUT(sessions: [
            session(id: "a", daysAgo: 0, durationSeconds: 180),
            session(id: "b", daysAgo: 0, durationSeconds: 120),
            session(id: "c", daysAgo: 1, durationSeconds: 600) // yesterday, excluded
        ])
        await sut.load()
        XCTAssertEqual(sut.state.minutesToday, 5) // (180+120)/60
        XCTAssertFalse(sut.state.isLoading)
    }

    func test_load_noTodaySessions_minutesZero() async {
        let sut = makeSUT(sessions: [
            session(id: "a", daysAgo: 2, durationSeconds: 300)
        ])
        await sut.load()
        XCTAssertEqual(sut.state.minutesToday, 0)
    }

    // MARK: - Real streak

    func test_load_usesProfileStreakWhenPresent() async {
        let sut = makeSUT(
            sessions: [session(id: "a", daysAgo: 0, durationSeconds: 60)],
            profileStreak: 7
        )
        await sut.load()
        XCTAssertEqual(sut.state.streakDays, 7)
    }

    func test_load_computesStreakFromSessions_whenNoProfile() async {
        let sut = makeSUT(sessions: [
            session(id: "a", daysAgo: 0, durationSeconds: 60),
            session(id: "b", daysAgo: 1, durationSeconds: 60),
            session(id: "c", daysAgo: 2, durationSeconds: 60)
        ])
        await sut.load()
        XCTAssertEqual(sut.state.streakDays, 3)
    }

    func test_activeDayStreak_brokenChain() {
        let sut = makeSUT()
        let sessions = [
            session(id: "a", daysAgo: 0, durationSeconds: 60),
            session(id: "b", daysAgo: 3, durationSeconds: 60) // gap breaks streak
        ]
        XCTAssertEqual(sut.activeDayStreak(in: sessions), 1)
    }

    // MARK: - snooze

    func test_snooze_setsDismissed() {
        let sut = makeSUT()
        sut.snooze()
        XCTAssertTrue(sut.state.isDismissed)
    }

    func test_snooze_doesNotChangeMetrics() async {
        let sut = makeSUT(sessions: [session(id: "a", daysAgo: 0, durationSeconds: 120)])
        await sut.load()
        let minutes = sut.state.minutesToday
        let streak = sut.state.streakDays
        sut.snooze()
        XCTAssertEqual(sut.state.minutesToday, minutes)
        XCTAssertEqual(sut.state.streakDays, streak)
    }
}
