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
    public let thumbnailName: String?

    public init(
        id: String,
        title: String,
        soundId: String,
        description: String,
        keywords: [String],
        thumbnailName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.soundId = soundId
        self.description = description
        self.keywords = keywords
        self.thumbnailName = thumbnailName
    }
}

/// Данные достижения для индексации в Spotlight.
public struct SpotlightAchievementItem: Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let category: String
    public let unlockedAt: Date
    public let thumbnailName: String?

    public init(
        id: String,
        title: String,
        description: String,
        category: String = "achievement",
        unlockedAt: Date,
        thumbnailName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.unlockedAt = unlockedAt
        self.thumbnailName = thumbnailName
    }
}

/// Данные завершённой сессии для индексации в Spotlight.
/// COPPA-safe: НЕТ имени ребёнка, только sound + date + score.
public struct SpotlightSessionItem: Sendable {
    public let id: String
    public let soundId: String
    public let date: Date
    public let score: Int
    public let totalAttempts: Int
    public let correctAttempts: Int

    public init(
        id: String,
        soundId: String,
        date: Date,
        score: Int,
        totalAttempts: Int = 0,
        correctAttempts: Int = 0
    ) {
        self.id = id
        self.soundId = soundId
        self.date = date
        self.score = score
        self.totalAttempts = totalAttempts
        self.correctAttempts = correctAttempts
    }
}

/// Данные словарной единицы (word unit) для rich keyword indexing.
/// Используется для индексации 6509 word units.
public struct SpotlightWordUnitItem: Sendable {
    public let id: String
    public let word: String
    public let soundId: String
    public let position: String   // initial / medial / final
    public let difficulty: String // easy / medium / hard

    public init(
        id: String,
        word: String,
        soundId: String,
        position: String,
        difficulty: String
    ) {
        self.id = id
        self.word = word
        self.soundId = soundId
        self.position = position
        self.difficulty = difficulty
    }
}

// MARK: - Protocol

public protocol SpotlightIndexerProtocol: Sendable {
    func indexLessons(_ lessons: [SpotlightLessonItem]) async throws
    func indexAchievements(_ achievements: [SpotlightAchievementItem]) async throws
    func indexRecentSessions(_ sessions: [SpotlightSessionItem]) async throws
    func indexWordUnits(_ units: [SpotlightWordUnitItem]) async throws
    func clearAll() async throws
    func clearDomain(_ domain: SpotlightDomain) async throws
}

// MARK: - SpotlightDomain

public enum SpotlightDomain: String, Sendable {
    case lessons      = "ru.happyspeech.spotlight.lessons"
    case achievements = "ru.happyspeech.spotlight.achievements"
    case sessions     = "ru.happyspeech.spotlight.sessions"
    case wordUnits    = "ru.happyspeech.spotlight.wordunits"
}

// MARK: - Live Implementation

/// Производственная реализация CoreSpotlight-индексатора.
/// Использует actor-изоляцию для Swift 6 strict concurrency.
/// Поддерживает:
///   - indexLessons: 16 уроков с rich keywords и thumbnail
///   - indexAchievements: 32 достижения
///   - indexRecentSessions: последние 30 сессий (COPPA-safe)
///   - indexWordUnits: batch-индексация 6509 word units (по 500 за раз)
///   - clearDomain: точечная очистка отдельного домена
public actor LiveSpotlightIndexer: SpotlightIndexerProtocol {

    // MARK: - Constants

    private let wordUnitBatchSize: Int = 500

    // MARK: - Dependencies

    private let logger = Logger(subsystem: "ru.happyspeech.app", category: "Spotlight")
    private let index = CSSearchableIndex.default()

    public init() {}

    // MARK: - Index Lessons

    public func indexLessons(_ lessons: [SpotlightLessonItem]) async throws {
        let items = lessons.map { lesson -> CSSearchableItem in
            let attrs = buildLessonAttributeSet(lesson)
            return CSSearchableItem(
                uniqueIdentifier: "lesson_\(lesson.id)",
                domainIdentifier: SpotlightDomain.lessons.rawValue,
                attributeSet: attrs
            )
        }
        try await index.indexSearchableItems(items)
        logger.info("Spotlight: проиндексировано \(items.count) уроков")
    }

    private func buildLessonAttributeSet(_ lesson: SpotlightLessonItem) -> CSSearchableItemAttributeSet {
        let attrs = CSSearchableItemAttributeSet(contentType: UTType.text)
        attrs.title = lesson.title
        attrs.contentDescription = lesson.description
        attrs.keywords = lesson.keywords + ["урок", "логопедия", lesson.soundId, "HappySpeech"]
        attrs.domainIdentifier = SpotlightDomain.lessons.rawValue
        attrs.relatedUniqueIdentifier = "lesson_\(lesson.id)"
        attrs.userCurated = true
        if let thumbName = lesson.thumbnailName {
            attrs.thumbnailData = loadThumbnailData(named: thumbName)
        }
        return attrs
    }

    // MARK: - Index Achievements

    public func indexAchievements(_ achievements: [SpotlightAchievementItem]) async throws {
        let items = achievements.map { ach -> CSSearchableItem in
            let attrs = buildAchievementAttributeSet(ach)
            return CSSearchableItem(
                uniqueIdentifier: "achievement_\(ach.id)",
                domainIdentifier: SpotlightDomain.achievements.rawValue,
                attributeSet: attrs
            )
        }
        try await index.indexSearchableItems(items)
        logger.info("Spotlight: проиндексировано \(items.count) достижений")
    }

    private func buildAchievementAttributeSet(_ ach: SpotlightAchievementItem) -> CSSearchableItemAttributeSet {
        let attrs = CSSearchableItemAttributeSet(contentType: UTType.text)
        attrs.title = ach.title
        attrs.contentDescription = ach.description
        attrs.keywords = ["достижение", "награда", "бейдж", "звезда", ach.category, "HappySpeech"]
        attrs.domainIdentifier = SpotlightDomain.achievements.rawValue
        if let thumbName = ach.thumbnailName {
            attrs.thumbnailData = loadThumbnailData(named: thumbName)
        }
        return attrs
    }

    // MARK: - Index Recent Sessions

    /// Индексирует последние 30 сессий.
    /// COPPA-safe: НЕТ имени ребёнка, только sound + score + date.
    public func indexRecentSessions(_ sessions: [SpotlightSessionItem]) async throws {
        let recentSessions = sessions.prefix(30)
        let items = recentSessions.map { session -> CSSearchableItem in
            let attrs = buildSessionAttributeSet(session)
            return CSSearchableItem(
                uniqueIdentifier: "session_\(session.id)",
                domainIdentifier: SpotlightDomain.sessions.rawValue,
                attributeSet: attrs
            )
        }
        try await index.indexSearchableItems(Array(items))
        logger.info("Spotlight: проиндексировано \(items.count) сессий")
    }

    private func buildSessionAttributeSet(_ session: SpotlightSessionItem) -> CSSearchableItemAttributeSet {
        let attrs = CSSearchableItemAttributeSet(contentType: UTType.text)
        attrs.title = String(
            format: String(localized: "spotlight.session.title %@"),
            session.soundId
        )
        let accuracyPercent: Int
        if session.totalAttempts > 0 {
            accuracyPercent = Int(Double(session.correctAttempts) / Double(session.totalAttempts) * 100)
        } else {
            accuracyPercent = session.score
        }
        attrs.contentDescription = String(
            format: String(localized: "spotlight.session.description %lld"),
            accuracyPercent
        )
        attrs.keywords = ["занятие", "урок", "звук", session.soundId, "логопедия", "HappySpeech"]
        attrs.domainIdentifier = SpotlightDomain.sessions.rawValue
        return attrs
    }

    // MARK: - Index Word Units (6509 слов, пакетами по 500)

    /// Индексирует 6509 словарных единиц пакетами по `wordUnitBatchSize` (500).
    /// Каждый word unit включает само слово, звук, позицию и сложность.
    public func indexWordUnits(_ units: [SpotlightWordUnitItem]) async throws {
        let batches = stride(from: 0, to: units.count, by: wordUnitBatchSize).map {
            Array(units[$0..<min($0 + wordUnitBatchSize, units.count)])
        }

        logger.info("Spotlight: начинаем индексацию \(units.count) word units в \(batches.count) пакетах")

        for (idx, batch) in batches.enumerated() {
            let items = batch.map { unit -> CSSearchableItem in
                let attrs = buildWordUnitAttributeSet(unit)
                return CSSearchableItem(
                    uniqueIdentifier: "word_\(unit.id)",
                    domainIdentifier: SpotlightDomain.wordUnits.rawValue,
                    attributeSet: attrs
                )
            }
            try await index.indexSearchableItems(items)
            logger.debug("Spotlight: пакет \(idx + 1)/\(batches.count) проиндексирован (\(batch.count) слов)")
        }
        logger.info("Spotlight: индексация word units завершена — итого \(units.count) слов")
    }

    private func buildWordUnitAttributeSet(_ unit: SpotlightWordUnitItem) -> CSSearchableItemAttributeSet {
        let attrs = CSSearchableItemAttributeSet(contentType: UTType.text)
        attrs.title = unit.word
        let posLabel = positionLabel(unit.position)
        let diffLabel = difficultyLabel(unit.difficulty)
        attrs.contentDescription = "Звук \(unit.soundId) • \(posLabel) • \(diffLabel)"
        attrs.keywords = [
            unit.word,
            "звук",
            unit.soundId,
            unit.position,
            unit.difficulty,
            "логопедия",
            "слово"
        ]
        attrs.domainIdentifier = SpotlightDomain.wordUnits.rawValue
        return attrs
    }

    // MARK: - Clear All

    public func clearAll() async throws {
        let allDomains = SpotlightDomain.allCases.map { $0.rawValue }
        try await index.deleteSearchableItems(withDomainIdentifiers: allDomains)
        logger.info("Spotlight: все индексы очищены")
    }

    // MARK: - Clear Domain

    public func clearDomain(_ domain: SpotlightDomain) async throws {
        try await index.deleteSearchableItems(withDomainIdentifiers: [domain.rawValue])
        logger.info("Spotlight: домен \(domain.rawValue, privacy: .public) очищен")
    }

    // MARK: - Private Helpers

    private func loadThumbnailData(named name: String) -> Data? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    private func positionLabel(_ position: String) -> String {
        switch position {
        case "initial": return "в начале слова"
        case "medial":  return "в середине слова"
        case "final":   return "в конце слова"
        default:        return position
        }
    }

    private func difficultyLabel(_ difficulty: String) -> String {
        switch difficulty {
        case "easy":   return "лёгкое"
        case "medium": return "среднее"
        case "hard":   return "сложное"
        default:       return difficulty
        }
    }
}

// MARK: - SpotlightDomain + CaseIterable

extension SpotlightDomain: CaseIterable {}

// MARK: - Mock Implementation

/// Мок-реализация для тестов и Preview.
public actor MockSpotlightIndexer: SpotlightIndexerProtocol {
    public var indexedLessons: [SpotlightLessonItem] = []
    public var indexedAchievements: [SpotlightAchievementItem] = []
    public var indexedSessions: [SpotlightSessionItem] = []
    public var indexedWordUnits: [SpotlightWordUnitItem] = []
    public var clearCallCount: Int = 0
    public var clearDomainCalls: [SpotlightDomain] = []

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

    public func indexWordUnits(_ units: [SpotlightWordUnitItem]) async throws {
        indexedWordUnits = units
    }

    public func clearAll() async throws {
        clearCallCount += 1
        indexedLessons = []
        indexedAchievements = []
        indexedSessions = []
        indexedWordUnits = []
    }

    public func clearDomain(_ domain: SpotlightDomain) async throws {
        clearDomainCalls.append(domain)
        switch domain {
        case .lessons:      indexedLessons = []
        case .achievements: indexedAchievements = []
        case .sessions:     indexedSessions = []
        case .wordUnits:    indexedWordUnits = []
        }
    }
}
