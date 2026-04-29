import CoreSpotlight
import Foundation
import OSLog
import UniformTypeIdentifiers

// MARK: - Data Transfer Objects

/// Данные урока для индексации в Spotlight. COPPA-safe: нет имени ребёнка.
public struct SpotlightLessonItem: Sendable {
    public let id: String
    public let title: String
    public let soundId: String
    public let description: String
    public let keywords: [String]

    public init(
        id: String,
        title: String,
        soundId: String,
        description: String,
        keywords: [String]
    ) {
        self.id = id
        self.title = title
        self.soundId = soundId
        self.description = description
        self.keywords = keywords
    }
}

/// Данные достижения для индексации в Spotlight.
public struct SpotlightAchievementItem: Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let unlockedAt: Date

    public init(
        id: String,
        title: String,
        description: String,
        unlockedAt: Date
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.unlockedAt = unlockedAt
    }
}

/// Данные завершённой сессии для индексации в Spotlight.
/// COPPA-safe: НЕТ имени ребёнка, только sound + date + score.
public struct SpotlightSessionItem: Sendable {
    public let id: String
    public let soundId: String
    public let date: Date
    public let score: Int

    public init(
        id: String,
        soundId: String,
        date: Date,
        score: Int
    ) {
        self.id = id
        self.soundId = soundId
        self.date = date
        self.score = score
    }
}

// MARK: - Protocol

public protocol SpotlightIndexerProtocol: Sendable {
    func indexLessons(_ lessons: [SpotlightLessonItem]) async throws
    func indexAchievements(_ achievements: [SpotlightAchievementItem]) async throws
    func indexRecentSessions(_ sessions: [SpotlightSessionItem]) async throws
    func clearAll() async throws
}

// MARK: - Live Implementation

/// Производственная реализация CoreSpotlight-индексатора.
/// Использует actor-изоляцию для Swift 6 strict concurrency.
public actor LiveSpotlightIndexer: SpotlightIndexerProtocol {

    private let logger = Logger(subsystem: "ru.happyspeech.app", category: "Spotlight")
    private let lessonDomain = "ru.happyspeech.spotlight.lessons"
    private let achievementDomain = "ru.happyspeech.spotlight.achievements"
    private let sessionDomain = "ru.happyspeech.spotlight.sessions"

    public init() {}

    // MARK: - Index Lessons

    public func indexLessons(_ lessons: [SpotlightLessonItem]) async throws {
        let items = lessons.map { lesson -> CSSearchableItem in
            let attrs = CSSearchableItemAttributeSet(contentType: UTType.text)
            attrs.title = lesson.title
            attrs.contentDescription = lesson.description
            attrs.keywords = lesson.keywords + ["урок", "логопедия", lesson.soundId]
            attrs.domainIdentifier = lessonDomain
            return CSSearchableItem(
                uniqueIdentifier: "lesson_\(lesson.id)",
                domainIdentifier: lessonDomain,
                attributeSet: attrs
            )
        }
        try await CSSearchableIndex.default().indexSearchableItems(items)
        logger.info("Spotlight: проиндексировано \(items.count) уроков")
    }

    // MARK: - Index Achievements

    public func indexAchievements(_ achievements: [SpotlightAchievementItem]) async throws {
        let items = achievements.map { ach -> CSSearchableItem in
            let attrs = CSSearchableItemAttributeSet(contentType: UTType.text)
            attrs.title = ach.title
            attrs.contentDescription = ach.description
            attrs.keywords = ["достижение", "награда", "бейдж", "звезда"]
            attrs.domainIdentifier = achievementDomain
            return CSSearchableItem(
                uniqueIdentifier: "achievement_\(ach.id)",
                domainIdentifier: achievementDomain,
                attributeSet: attrs
            )
        }
        try await CSSearchableIndex.default().indexSearchableItems(items)
        logger.info("Spotlight: проиндексировано \(items.count) достижений")
    }

    // MARK: - Index Recent Sessions

    /// Индексирует последние 30 сессий.
    /// COPPA-safe: НЕТ имени ребёнка, только sound + score.
    public func indexRecentSessions(_ sessions: [SpotlightSessionItem]) async throws {
        let recentSessions = sessions.prefix(30)
        let items = recentSessions.map { session -> CSSearchableItem in
            let attrs = CSSearchableItemAttributeSet(contentType: UTType.text)
            attrs.title = String(format: String(localized: "spotlight.session.title %@"), session.soundId)
            attrs.contentDescription = String(format: String(localized: "spotlight.session.description %lld"), session.score)
            attrs.keywords = ["занятие", "урок", "звук", session.soundId, "логопедия"]
            attrs.domainIdentifier = sessionDomain
            return CSSearchableItem(
                uniqueIdentifier: "session_\(session.id)",
                domainIdentifier: sessionDomain,
                attributeSet: attrs
            )
        }
        try await CSSearchableIndex.default().indexSearchableItems(Array(items))
        logger.info("Spotlight: проиндексировано \(items.count) сессий")
    }

    // MARK: - Clear All

    public func clearAll() async throws {
        try await CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [
            lessonDomain,
            achievementDomain,
            sessionDomain
        ])
        logger.info("Spotlight: все индексы очищены")
    }
}

// MARK: - Mock Implementation

/// Мок-реализация для тестов и Preview.
public actor MockSpotlightIndexer: SpotlightIndexerProtocol {
    public var indexedLessons: [SpotlightLessonItem] = []
    public var indexedAchievements: [SpotlightAchievementItem] = []
    public var indexedSessions: [SpotlightSessionItem] = []
    public var clearCallCount: Int = 0

    public init() {}

    public func indexLessons(_ lessons: [SpotlightLessonItem]) async throws {
        indexedLessons = lessons
    }

    public func indexAchievements(_ achievements: [SpotlightAchievementItem]) async throws {
        indexedAchievements = achievements
    }

    public func indexRecentSessions(_ sessions: [SpotlightSessionItem]) async throws {
        indexedSessions = Array(sessions.prefix(30))
    }

    public func clearAll() async throws {
        clearCallCount += 1
        indexedLessons = []
        indexedAchievements = []
        indexedSessions = []
    }
}
