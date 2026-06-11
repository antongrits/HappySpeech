import XCTest
@testable import HappySpeech

// MARK: - SessionPersistenceCoordinatorTests
//
// P0-3 регрессия: `LiveSessionPersistenceCoordinator.persistAndSync` обязан после
// сохранения сессии атомарно обновить агрегаты профиля ребёнка — lastSessionAt,
// totalSessionMinutes (инкремент) и currentStreak (trailing-run по реальным
// сессиям). Раньше эти поля никогда не писались, поэтому ParentHome/Family/
// Specialist/Sync читали вечные нули.

final class SessionPersistenceCoordinatorTests: XCTestCase {

    private func makeCoordinator(
        childRepo: SpyChildRepository,
        sessionRepo: SpySessionRepository
    ) -> LiveSessionPersistenceCoordinator {
        // Анонимный пользователь: ветка облачного синка не выполняется, проверяем
        // ровно агрегаты профиля (они обновляются ДО проверки auth).
        LiveSessionPersistenceCoordinator(
            sessionRepository: sessionRepo,
            childRepository: childRepo,
            syncService: MockSyncService(),
            authService: MockAuthService(initialUser: nil)
        )
    }

    func test_persistAndSync_updatesLastSessionAtAndMinutes() async throws {
        let childId = "child-agg-1"
        let child = TestDataBuilder.childProfile(id: childId, totalSessionMinutes: 10, currentStreak: 0)
        let childRepo = SpyChildRepository(children: [child])
        let sessionRepo = SpySessionRepository(sessions: [])
        let coordinator = makeCoordinator(childRepo: childRepo, sessionRepo: sessionRepo)

        let now = Date()
        let session = TestDataBuilder.session(
            childId: childId,
            date: now,
            durationSeconds: 300 // 5 минут
        )

        await coordinator.persistAndSync(session)

        XCTAssertEqual(childRepo.updateAggregatesCallCount, 1)
        XCTAssertEqual(childRepo.lastAggregatesChildId, childId)
        XCTAssertEqual(childRepo.lastAggregatesDate, now)
        XCTAssertEqual(childRepo.lastAggregatesAddedMinutes, 5)

        let updated = try await childRepo.fetch(id: childId)
        XCTAssertEqual(updated.totalSessionMinutes, 15) // 10 + 5
        XCTAssertEqual(updated.lastSessionAt, now)
    }

    func test_persistAndSync_setsStreakToOneOnFirstSession() async throws {
        let childId = "child-agg-2"
        let childRepo = SpyChildRepository(
            children: [TestDataBuilder.childProfile(id: childId, currentStreak: 0)]
        )
        let sessionRepo = SpySessionRepository(sessions: [])
        let coordinator = makeCoordinator(childRepo: childRepo, sessionRepo: sessionRepo)

        let session = TestDataBuilder.session(childId: childId, date: Date(), durationSeconds: 120)
        await coordinator.persistAndSync(session)

        XCTAssertEqual(childRepo.lastAggregatesStreak, 1)
        let updated = try await childRepo.fetch(id: childId)
        XCTAssertEqual(updated.currentStreak, 1)
    }

    func test_persistAndSync_computesTrailingRunStreakAcrossDays() async throws {
        let childId = "child-agg-3"
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
            let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)
        else {
            return XCTFail("Calendar date math failed")
        }

        // Уже есть сессии за позавчера и вчера; сегодня — третья подряд.
        let existing = [
            TestDataBuilder.session(id: "s1", childId: childId, date: twoDaysAgo, durationSeconds: 100),
            TestDataBuilder.session(id: "s2", childId: childId, date: yesterday, durationSeconds: 100)
        ]
        let childRepo = SpyChildRepository(
            children: [TestDataBuilder.childProfile(id: childId, currentStreak: 2)]
        )
        let sessionRepo = SpySessionRepository(sessions: existing)
        let coordinator = makeCoordinator(childRepo: childRepo, sessionRepo: sessionRepo)

        let todaySession = TestDataBuilder.session(
            id: "s3", childId: childId, date: today, durationSeconds: 100
        )
        await coordinator.persistAndSync(todaySession)

        XCTAssertEqual(childRepo.lastAggregatesStreak, 3)
        let updated = try await childRepo.fetch(id: childId)
        XCTAssertEqual(updated.currentStreak, 3)
    }

    func test_persistAndSync_emptyChildId_doesNotUpdateAggregates() async throws {
        let childRepo = SpyChildRepository(children: [])
        let sessionRepo = SpySessionRepository(sessions: [])
        let coordinator = makeCoordinator(childRepo: childRepo, sessionRepo: sessionRepo)

        let session = TestDataBuilder.session(childId: "", date: Date(), durationSeconds: 120)
        await coordinator.persistAndSync(session)

        XCTAssertEqual(childRepo.updateAggregatesCallCount, 0)
    }

    func test_persistAndSync_zeroDuration_addsNoMinutes() async throws {
        let childId = "child-agg-4"
        let childRepo = SpyChildRepository(
            children: [TestDataBuilder.childProfile(id: childId, totalSessionMinutes: 7)]
        )
        let sessionRepo = SpySessionRepository(sessions: [])
        let coordinator = makeCoordinator(childRepo: childRepo, sessionRepo: sessionRepo)

        let session = TestDataBuilder.session(childId: childId, date: Date(), durationSeconds: 0)
        await coordinator.persistAndSync(session)

        XCTAssertEqual(childRepo.lastAggregatesAddedMinutes, 0)
        let updated = try await childRepo.fetch(id: childId)
        XCTAssertEqual(updated.totalSessionMinutes, 7)
    }
}
