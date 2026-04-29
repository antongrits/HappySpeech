@testable import HappySpeech
import XCTest

// MARK: - SpotlightIndexerTests
// ==================================================================================
// 6 unit-тестов для SpotlightIndexer (Block K — K.7).
//
// Все тесты работают с MockSpotlightIndexer — без реального CoreSpotlight.
// Проверяется: indexLessons / indexAchievements / indexRecentSessions / clearAll /
//              prefix(30) ограничение / COPPA (нет имён детей).
// ==================================================================================

final class SpotlightIndexerTests: XCTestCase {

    // MARK: - Factories

    private func makeMock() -> MockSpotlightIndexer {
        MockSpotlightIndexer()
    }

    private func makeLessons(count: Int) -> [SpotlightLessonItem] {
        (0..<count).map { i in
            SpotlightLessonItem(
                id: "lesson-\(i)",
                title: "Урок звука Р — \(i)",
                soundId: "Р",
                description: "Описание \(i)",
                keywords: ["р", "сонор"]
            )
        }
    }

    private func makeAchievements(count: Int) -> [SpotlightAchievementItem] {
        (0..<count).map { i in
            SpotlightAchievementItem(
                id: "ach-\(i)",
                title: "Достижение \(i)",
                description: "Описание достижения \(i)",
                unlockedAt: Date()
            )
        }
    }

    private func makeSessions(count: Int) -> [SpotlightSessionItem] {
        (0..<count).map { i in
            SpotlightSessionItem(
                id: "session-\(i)",
                soundId: "Ш",
                date: Date(),
                score: i % 100
            )
        }
    }

    // MARK: - Tests

    /// K.7.1 — indexLessons сохраняет все переданные уроки
    func testIndexLessons_storesAllLessons() async throws {
        let mock = makeMock()
        let lessons = makeLessons(count: 5)

        try await mock.indexLessons(lessons)

        let stored = await mock.indexedLessons
        XCTAssertEqual(stored.count, 5)
        XCTAssertEqual(stored.first?.soundId, "Р")
    }

    /// K.7.2 — indexAchievements сохраняет все достижения
    func testIndexAchievements_storesAllAchievements() async throws {
        let mock = makeMock()
        let achievements = makeAchievements(count: 3)

        try await mock.indexAchievements(achievements)

        let stored = await mock.indexedAchievements
        XCTAssertEqual(stored.count, 3)
        XCTAssertEqual(stored.first?.title, "Достижение 0")
    }

    /// K.7.3 — indexRecentSessions сохраняет переданные сессии (< 30)
    func testIndexRecentSessions_storesSessionsUnder30() async throws {
        let mock = makeMock()
        let sessions = makeSessions(count: 10)

        try await mock.indexRecentSessions(sessions)

        let stored = await mock.indexedSessions
        XCTAssertEqual(stored.count, 10)
        XCTAssertEqual(stored.first?.soundId, "Ш")
    }

    /// K.7.4 — indexRecentSessions ограничивает до prefix(30) сессий
    func testIndexRecentSessions_limitsTo30() async throws {
        let mock = makeMock()
        let sessions = makeSessions(count: 50)

        try await mock.indexRecentSessions(sessions)

        let stored = await mock.indexedSessions
        XCTAssertEqual(stored.count, 30, "Должно быть не более 30 сессий в индексе")
    }

    /// K.7.5 — clearAll очищает все коллекции и увеличивает счётчик
    func testClearAll_clearsAllCollectionsAndIncrementsCount() async throws {
        let mock = makeMock()

        // Предварительно добавляем данные
        try await mock.indexLessons(makeLessons(count: 3))
        try await mock.indexAchievements(makeAchievements(count: 2))
        try await mock.indexRecentSessions(makeSessions(count: 5))

        // Очищаем
        try await mock.clearAll()

        let lessons = await mock.indexedLessons
        let achievements = await mock.indexedAchievements
        let sessions = await mock.indexedSessions
        let callCount = await mock.clearCallCount

        XCTAssertTrue(lessons.isEmpty, "Уроки должны быть очищены")
        XCTAssertTrue(achievements.isEmpty, "Достижения должны быть очищены")
        XCTAssertTrue(sessions.isEmpty, "Сессии должны быть очищены")
        XCTAssertEqual(callCount, 1, "clearAll должен быть вызван ровно 1 раз")
    }

    /// K.7.6 — COPPA: SpotlightSessionItem не содержит имени ребёнка
    func testSessionItem_coppa_noChildName() {
        let session = SpotlightSessionItem(
            id: "test-session",
            soundId: "Р",
            date: Date(),
            score: 80
        )

        // Проверяем что ни одно поле не содержит имён детей
        // (структура намеренно не имеет поля childName / childId)
        let mirror = Mirror(reflecting: session)
        let propertyNames = mirror.children.compactMap { $0.label }

        XCTAssertFalse(propertyNames.contains("childName"), "Не должно быть поля childName — COPPA")
        XCTAssertFalse(propertyNames.contains("childId"), "Не должно быть поля childId — COPPA")
        XCTAssertEqual(session.soundId, "Р")
        XCTAssertEqual(session.score, 80)
    }
}
