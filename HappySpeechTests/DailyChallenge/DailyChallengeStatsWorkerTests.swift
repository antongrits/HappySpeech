@testable import HappySpeech
import XCTest

// MARK: - DailyChallengeStatsWorkerTests
//
// Покрывает: fetchTodaySessions, progress(for:targetSound:sessions:), computeStreak.
// Зависимости: SpySessionRepository, SpyChildRepository.

@MainActor
final class DailyChallengeStatsWorkerTests: XCTestCase {

    // MARK: - fetchTodaySessions

    func test_fetchTodaySessions_returnsOnlyTodaySessions() async {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let todaySession = TestDataBuilder.session(childId: "child-001", date: today)
        let yesterdaySession = TestDataBuilder.session(childId: "child-001", date: yesterday)
        let repo = SpySessionRepository(sessions: [todaySession, yesterdaySession])
        let childRepo = SpyChildRepository()
        let sut = DailyChallengeStatsWorker(sessionRepository: repo, childRepository: childRepo)

        let result = await sut.fetchTodaySessions(childId: "child-001", day: today)

        XCTAssertEqual(result.count, 1, "Должна вернуться только сегодняшняя сессия")
    }

    func test_fetchTodaySessions_returnsEmptyWhenNoTodaySessions() async {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let oldSession = TestDataBuilder.session(childId: "child-001", date: yesterday)
        let repo = SpySessionRepository(sessions: [oldSession])
        let childRepo = SpyChildRepository()
        let sut = DailyChallengeStatsWorker(sessionRepository: repo, childRepository: childRepo)

        let result = await sut.fetchTodaySessions(childId: "child-001", day: Date())

        XCTAssertTrue(result.isEmpty, "Не должно быть сессий если нет сегодняшних")
    }

    func test_fetchTodaySessions_returnsEmptyOnRepositoryFailure() async {
        let repo = SpySessionRepository(sessions: [])
        repo.shouldFail = true
        let childRepo = SpyChildRepository()
        let sut = DailyChallengeStatsWorker(sessionRepository: repo, childRepository: childRepo)

        let result = await sut.fetchTodaySessions(childId: "child-001", day: Date())

        XCTAssertTrue(result.isEmpty, "При ошибке репозитория должен вернуть пустой массив")
    }

    // MARK: - progress: .repetitions

    func test_progress_repetitions_sumsCorrectAttempts() {
        let sessions = [
            TestDataBuilder.session(correctAttempts: 5),
            TestDataBuilder.session(correctAttempts: 3)
        ]
        let repo = SpySessionRepository(sessions: [])
        let childRepo = SpyChildRepository()
        let sut = DailyChallengeStatsWorker(sessionRepository: repo, childRepository: childRepo)

        let result = sut.progress(for: .repetitions, targetSound: "Р", sessions: sessions)

        XCTAssertEqual(result, 8, "Прогресс .repetitions должен суммировать correctAttempts")
    }

    func test_progress_repetitions_returnsZeroForEmptySessions() {
        let repo = SpySessionRepository(sessions: [])
        let childRepo = SpyChildRepository()
        let sut = DailyChallengeStatsWorker(sessionRepository: repo, childRepository: childRepo)

        let result = sut.progress(for: .repetitions, targetSound: "Р", sessions: [])

        XCTAssertEqual(result, 0, "Пустые сессии должны давать 0")
    }

    // MARK: - progress: .minutes

    func test_progress_minutes_convertsTotalSecondsToMinutes() {
        let sessions = [
            TestDataBuilder.session(durationSeconds: 120),
            TestDataBuilder.session(durationSeconds: 60)
        ]
        let repo = SpySessionRepository(sessions: [])
        let childRepo = SpyChildRepository()
        let sut = DailyChallengeStatsWorker(sessionRepository: repo, childRepository: childRepo)

        let result = sut.progress(for: .minutes, targetSound: "Р", sessions: sessions)

        XCTAssertEqual(result, 3, "180 секунд = 3 минуты")
    }

    func test_progress_minutes_roundsDownForPartialMinutes() {
        let sessions = [TestDataBuilder.session(durationSeconds: 90)]
        let repo = SpySessionRepository(sessions: [])
        let childRepo = SpyChildRepository()
        let sut = DailyChallengeStatsWorker(sessionRepository: repo, childRepository: childRepo)

        let result = sut.progress(for: .minutes, targetSound: "Р", sessions: sessions)

        XCTAssertEqual(result, 1, "90 секунд должны давать 1 минуту (floor)")
    }

    // MARK: - progress: .soundFocus

    func test_progress_soundFocus_countsOnlyMatchingTargetSound() {
        let sessions = [
            TestDataBuilder.session(targetSound: "Р", correctAttempts: 4),
            TestDataBuilder.session(targetSound: "С", correctAttempts: 6)
        ]
        let repo = SpySessionRepository(sessions: [])
        let childRepo = SpyChildRepository()
        let sut = DailyChallengeStatsWorker(sessionRepository: repo, childRepository: childRepo)

        let result = sut.progress(for: .soundFocus, targetSound: "Р", sessions: sessions)

        XCTAssertEqual(result, 4, "Должны считаться только correctAttempts с targetSound=\"Р\"")
    }

    func test_progress_soundFocus_returnsZeroWhenNoMatchingSessions() {
        let sessions = [TestDataBuilder.session(targetSound: "С", correctAttempts: 5)]
        let repo = SpySessionRepository(sessions: [])
        let childRepo = SpyChildRepository()
        let sut = DailyChallengeStatsWorker(sessionRepository: repo, childRepository: childRepo)

        let result = sut.progress(for: .soundFocus, targetSound: "Р", sessions: sessions)

        XCTAssertEqual(result, 0, "Нет сессий с targetSound=\"Р\" — прогресс 0")
    }

    // MARK: - progress: .streakKeep

    func test_progress_streakKeep_returns1WhenSessionsPresent() {
        let sessions = [TestDataBuilder.session()]
        let repo = SpySessionRepository(sessions: [])
        let childRepo = SpyChildRepository()
        let sut = DailyChallengeStatsWorker(sessionRepository: repo, childRepository: childRepo)

        let result = sut.progress(for: .streakKeep, targetSound: "Р", sessions: sessions)

        XCTAssertEqual(result, 1, "При наличии хотя бы одной сессии прогресс = 1")
    }

    func test_progress_streakKeep_returns0WhenNoSessions() {
        let repo = SpySessionRepository(sessions: [])
        let childRepo = SpyChildRepository()
        let sut = DailyChallengeStatsWorker(sessionRepository: repo, childRepository: childRepo)

        let result = sut.progress(for: .streakKeep, targetSound: "Р", sessions: [])

        XCTAssertEqual(result, 0, "Без сессий прогресс = 0")
    }

    // MARK: - computeStreak

    func test_computeStreak_returnsCurrentStreakFromProfile() async {
        let profile = TestDataBuilder.childProfile(
            id: "child-001",
            currentStreak: 7
        )
        let repo = SpySessionRepository(sessions: [])
        let childRepo = SpyChildRepository(children: [profile])
        let sut = DailyChallengeStatsWorker(sessionRepository: repo, childRepository: childRepo)

        let streak = await sut.computeStreak(childId: "child-001")

        XCTAssertEqual(streak.current, 7, "streak.current должен браться из профиля")
        XCTAssertGreaterThanOrEqual(streak.longest, streak.current)
    }

    func test_computeStreak_returnsZeroOnRepositoryFailure() async {
        let repo = SpySessionRepository(sessions: [])
        let childRepo = SpyChildRepository()
        childRepo.shouldFail = true
        let sut = DailyChallengeStatsWorker(sessionRepository: repo, childRepository: childRepo)

        let streak = await sut.computeStreak(childId: "child-001")

        XCTAssertEqual(streak.current, 0, "При ошибке репозитория streak.current должен быть 0")
        XCTAssertEqual(streak.longest, 0)
        XCTAssertNil(streak.lastSessionISO)
    }

    func test_computeStreak_setsLastSessionISO_whenLastSessionAtNotNil() async {
        let lastDate = Date(timeIntervalSince1970: 1_700_000_000)
        let profile = TestDataBuilder.childProfile(id: "child-001", lastSessionAt: lastDate)
        let repo = SpySessionRepository(sessions: [])
        let childRepo = SpyChildRepository(children: [profile])
        let sut = DailyChallengeStatsWorker(sessionRepository: repo, childRepository: childRepo)

        let streak = await sut.computeStreak(childId: "child-001")

        XCTAssertNotNil(streak.lastSessionISO, "lastSessionISO должен быть установлен")
    }
}
