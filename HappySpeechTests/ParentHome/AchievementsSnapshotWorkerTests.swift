@testable import HappySpeech
import XCTest

// MARK: - AchievementsSnapshotWorkerTests
//
// Чистая функция — нет I/O, нет асинхронности. Все пути тестируются напрямую.

final class AchievementsSnapshotWorkerTests: XCTestCase {

    // MARK: - Helpers

    private func makeSession(
        id: String = UUID().uuidString,
        childId: String = "c-001",
        daysAgo: Int = 0,
        totalAttempts: Int = 10,
        correctAttempts: Int = 8,
        sound: String = "Р"
    ) -> SessionDTO {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return SessionDTO(
            id: id,
            childId: childId,
            date: date,
            templateType: TemplateType.listenAndChoose.rawValue,
            targetSound: sound,
            stage: CorrectionStage.wordInit.rawValue,
            durationSeconds: 180,
            totalAttempts: totalAttempts,
            correctAttempts: correctAttempts,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
    }

    // MARK: - buildSnapshot: empty sessions

    func test_buildSnapshot_emptySessions_returnsEmptyArray() {
        let result = AchievementsSnapshotWorker.buildSnapshot(
            from: [],
            childName: "Маша"
        )
        XCTAssertTrue(result.isEmpty, "Без сессий нет достижений")
    }

    // MARK: - buildSnapshot: perfect sessions (100%)

    func test_buildSnapshot_perfectSession_addsPerfectAchievement() {
        let session = makeSession(totalAttempts: 5, correctAttempts: 5)
        let result = AchievementsSnapshotWorker.buildSnapshot(from: [session], childName: "Ваня")
        let perfect = result.first(where: { $0.id == "perfect_session" })
        XCTAssertNotNil(perfect, "100% сессия должна давать achievement «perfect_session»")
    }

    func test_buildSnapshot_imperfectSession_noPerfectAchievement() {
        let session = makeSession(totalAttempts: 5, correctAttempts: 4)
        let result = AchievementsSnapshotWorker.buildSnapshot(from: [session], childName: "Лена")
        let perfect = result.first(where: { $0.id == "perfect_session" })
        XCTAssertNil(perfect, "Не 100% → нет perfect_session achievement")
    }

    // MARK: - buildSnapshot: unique sounds

    func test_buildSnapshot_oneSoundSession_addsFirstSoundAchievement() {
        let session = makeSession(sound: "Р")
        let result = AchievementsSnapshotWorker.buildSnapshot(from: [session], childName: "Рома")
        let sounds = result.first(where: { $0.id.hasPrefix("first_sounds_") })
        XCTAssertNotNil(sounds, "При наличии звука должен быть achievement «first_sounds_»")
    }

    func test_buildSnapshot_multipleUniqueSounds_idContainsSoundCount() {
        let s1 = makeSession(sound: "Р")
        let s2 = makeSession(sound: "Ш")
        let result = AchievementsSnapshotWorker.buildSnapshot(from: [s1, s2], childName: "Аня")
        let sounds = result.first(where: { $0.id == "first_sounds_2" })
        XCTAssertNotNil(sounds, "Два уникальных звука → id = first_sounds_2")
    }

    // MARK: - buildSnapshot: 10 sessions

    func test_buildSnapshot_tenSessions_addsTenSessionsAchievement() {
        let sessions = (0..<10).map { i in makeSession(id: "s-\(i)", daysAgo: i) }
        let result = AchievementsSnapshotWorker.buildSnapshot(from: sessions, childName: "Петя")
        let ten = result.first(where: { $0.id == "sessions_10" })
        XCTAssertNotNil(ten, "10 сессий → achievement «sessions_10»")
    }

    func test_buildSnapshot_lessThanTenSessions_noTenAchievement() {
        let sessions = (0..<9).map { i in makeSession(id: "s-\(i)") }
        let result = AchievementsSnapshotWorker.buildSnapshot(from: sessions, childName: "Таня")
        let ten = result.first(where: { $0.id == "sessions_10" })
        XCTAssertNil(ten)
    }

    // MARK: - buildSnapshot: streak 7+

    func test_buildSnapshot_streakSevenDays_addsStreakAchievement() {
        // Сессии за 7 последовательных дней
        let sessions = (0..<7).map { i in makeSession(id: "s-\(i)", daysAgo: i) }
        let result = AchievementsSnapshotWorker.buildSnapshot(from: sessions, childName: "Юля")
        let streak = result.first(where: { $0.id.hasPrefix("streak_") })
        XCTAssertNotNil(streak, "7 последовательных дней → streak achievement")
    }

    func test_buildSnapshot_nonConsecutiveDays_noStreakAchievement() {
        // Пропуск дня → streak < 7
        let sessions = [0, 2, 4, 6, 8, 10, 12].map { i in makeSession(id: "s-\(i)", daysAgo: i) }
        let result = AchievementsSnapshotWorker.buildSnapshot(from: sessions, childName: "Коля")
        let streak = result.first(where: { $0.id.hasPrefix("streak_") })
        XCTAssertNil(streak, "Непоследовательные дни → нет streak achievement")
    }

    // MARK: - buildSnapshot: excellent sound (>= 90% за 5 сессий)

    func test_buildSnapshot_excellentSound_addsExcellentAchievement() {
        // 5 сессий звука «Р» с accuracy 0.9 (correctAttempts=9/10)
        let sessions = (0..<5).map { i in
            makeSession(id: "s-\(i)", daysAgo: i, totalAttempts: 10, correctAttempts: 9, sound: "Р")
        }
        let result = AchievementsSnapshotWorker.buildSnapshot(from: sessions, childName: "Маша")
        let excellent = result.first(where: { $0.id == "excellent_Р" })
        XCTAssertNotNil(excellent, "5 сессий >= 90% по звуку Р → excellent achievement")
    }

    func test_buildSnapshot_onlyFourSessions_noExcellentAchievement() {
        // Только 4 сессии по звуку — не хватает 5
        let sessions = (0..<4).map { i in
            makeSession(id: "s-\(i)", totalAttempts: 10, correctAttempts: 10, sound: "С")
        }
        let result = AchievementsSnapshotWorker.buildSnapshot(from: sessions, childName: "Оля")
        let excellent = result.first(where: { $0.id == "excellent_С" })
        XCTAssertNil(excellent, "4 сессии не достаточно для excellent achievement")
    }

    // MARK: - buildSnapshot: limit

    func test_buildSnapshot_limit_doesNotExceedLimit() {
        let sessions = (0..<7).map { i in makeSession(id: "s-\(i)", daysAgo: i) }
            + (0..<10).map { i in makeSession(id: "t-\(i)", totalAttempts: 5, correctAttempts: 5) }
        let result = AchievementsSnapshotWorker.buildSnapshot(
            from: sessions, childName: "Тест", limit: 3
        )
        XCTAssertLessThanOrEqual(result.count, 3, "Результат не должен превышать limit")
    }

    // MARK: - buildSnapshot: sorted by unlockedAt descending

    func test_buildSnapshot_sortedByUnlockedAtDescending() {
        let perfectSession = makeSession(id: "p-0", daysAgo: 5, totalAttempts: 5, correctAttempts: 5)
        let sessions = [perfectSession] + (0..<10).map { i in makeSession(id: "m-\(i)", daysAgo: i) }
        let result = AchievementsSnapshotWorker.buildSnapshot(from: sessions, childName: "Сортировка")
        for i in 1..<result.count {
            XCTAssertGreaterThanOrEqual(
                result[i-1].unlockedAt, result[i].unlockedAt,
                "Достижения должны быть отсортированы по убыванию unlockedAt"
            )
        }
    }
}
