import Foundation

// MARK: - WorldMap VIP Models
//
// Карта звуков для kid-контура: 5 цветных зон (свистящие, шипящие, соноры,
// заднеязычные, грамматика). Каждая зона раскрывается в WorldMapZone и далее
// — в LessonPlayer. Прогресс хранится в Realm и приходит из репозитория.

enum WorldMapModels {

    // MARK: - LoadMap

    enum LoadMap {
        struct Request: Sendable {
            let childId: String
            let highlightedSound: String?
            let childAge: Int?
        }

        struct Response: Sendable {
            let zones: [WorldZone]
            let islands: [MapIsland]
            let collectibles: [MapCollectible]
            let totalStars: Int
            let highlightedZoneId: String?
            let dailyStreak: Int
            let lyalyaIslandId: String
            let recommendedIslandId: String?
            let recommendedLevelId: String?
        }

        struct ViewModel: Sendable {
            let zones: [WorldZoneCard]
            let highlightedZoneId: String?
            let totalStarsLabel: String
            let totalProgressFraction: Double
            let streakLabel: String
            let hasStreak: Bool
            let summaryAccessibilityLabel: String
            let lyalyaIslandId: String
            let recommendedIslandId: String?
            let recommendedLevelId: String?
        }
    }

    // MARK: - SelectZone

    enum SelectZone {
        struct Request: Sendable {
            let zoneId: String
        }

        struct Response: Sendable {
            let zone: WorldZone
            let canOpen: Bool
        }

        struct ViewModel: Sendable {
            let zoneId: String
            let canOpen: Bool
            let toastMessage: String?
        }
    }

    // MARK: - OpenZone

    enum OpenZone {
        struct Request: Sendable {
            let zoneId: String
        }
        struct Response: Sendable {
            let zoneId: String
            let primarySound: String
        }
    }

    // MARK: - LoadZoneDetail

    /// Запрос детальной карточки зоны для bottom sheet (звуки, методика, уровни).
    enum LoadZoneDetail {
        struct Request: Sendable {
            let zoneId: String
        }

        struct Response: Sendable {
            let zone: WorldZone
            let recommendedLessonCount: Int
            let estimatedMinutesPerSession: Int
            let prerequisiteZoneName: String?
            let levels: [MapLevel]
            let recommendedLevelId: String?
            let unlocksNeeded: Int
        }

        struct ViewModel: Sendable {
            let zoneId: String
            let name: String
            let icon: String
            let description: String
            let soundsLabel: String
            let progressLabel: String
            let progress: Double
            let lessonsLabel: String
            let recommendedLabel: String
            let durationLabel: String
            let isLocked: Bool
            let prerequisiteHint: String?
            let ctaTitle: String
            /// Имя цвета из палитры `ColorTokens.Brand.*` (маппинг — на стороне View).
            let colorName: String
            let accessibilityLabel: String
            let levels: [MapLevel]
            let recommendedLevelId: String?
            let unlocksNeeded: Int
        }
    }

    // MARK: - RefreshProgress

    /// Запрос обновления прогресса (после возврата из LessonPlayer).
    enum RefreshProgress {
        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let zones: [WorldZone]
            let totalStars: Int
            let dailyStreak: Int
        }

        struct ViewModel: Sendable {
            let zones: [WorldZoneCard]
            let totalStarsLabel: String
            let totalProgressFraction: Double
            let streakLabel: String
            let hasStreak: Bool
            let summaryAccessibilityLabel: String
        }
    }

    // MARK: - Failure

    enum Failure {
        struct Response: Sendable { let message: String }
        struct ViewModel: Sendable { let toastMessage: String }
    }

    // MARK: - TapLyalya

    enum TapLyalya {
        struct Request: Sendable {}
    }

    // MARK: - CollectTreasure

    enum CollectTreasure {
        struct Request: Sendable { let collectibleId: String }
        struct Response: Sendable {
            let collectible: MapCollectible
            let totalStars: Int
            let remainingCollectibles: [MapCollectible]
        }
        struct ViewModel: Sendable {
            let collectibleIcon: String
            let totalStarsLabel: String
            let toastMessage: String
            let remainingCollectibles: [MapCollectible]
        }
    }

    // MARK: - SelectLevel

    enum SelectLevel {
        struct Request: Sendable { let levelId: String }
        struct Response: Sendable {
            let level: MapLevel
            let islandId: String
            let zoneId: String
        }
        struct ViewModel: Sendable {
            let levelId: String
            let islandId: String
            let zoneId: String
            let levelName: String
        }
    }

    // MARK: - AdaptiveRecommendation

    enum AdaptiveRecommendation {
        struct Request: Sendable { let childId: String }
        struct Response: Sendable {
            let recommendedIslandId: String?
            let recommendedLevelId: String?
            let voiceHint: String
        }
        struct ViewModel: Sendable {
            let recommendedIslandId: String?
            let recommendedLevelId: String?
            let voiceHint: String
        }
    }

    // MARK: - RecordSession

    enum RecordSession {
        struct Request: Sendable {
            let islandId: String
            let levelId: String
            let successRate: Double
            let fatigueDetected: Bool
        }
    }

    // MARK: - VoicePrompt

    enum VoicePrompt {
        enum Context: Sendable {
            case islandUnlocked(name: String)
            case levelCompleted(levelName: String, islandName: String)
            case nearUnlock(name: String, count: Int)
            case firstVisit
            case encouragement
        }
        struct Request: Sendable { let context: Context }
        struct Response: Sendable {
            let text: String
            let isLyalya: Bool
        }
        struct ViewModel: Sendable {
            let text: String
            let isLyalya: Bool
        }
    }

    // MARK: - LoadZoneDetail (extended)

    enum LoadZoneDetailExtended {
        struct Response: Sendable {
            let zone: WorldZone
            let recommendedLessonCount: Int
            let estimatedMinutesPerSession: Int
            let prerequisiteZoneName: String?
            let levels: [MapLevel]
            let recommendedLevelId: String?
            let unlocksNeeded: Int
        }
    }
}

// MARK: - Domain types

/// Категория-зона на карте звуков. Каждая объединяет фонетически близкие звуки.
struct WorldZone: Sendable, Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String
    let sounds: [String]
    var progress: Float        // 0.0–1.0
    var completedLessons: Int
    var totalLessons: Int
    let colorName: String
    let isLocked: Bool
    /// Нормализованная позиция острова на канвасе [0..1, 0..1]. У сетки игнорируется.
    let position: CGPoint
    /// Маркер «текущего» острова — здесь стоит Ляля-маскот.
    let isCurrentLocation: Bool
    /// Краткое методическое описание зоны (для detailSheet).
    let description: String
    /// ID зоны-предпосылки (если заблокирована — показываем, что надо пройти раньше).
    let prerequisiteZoneId: String?
    /// Рекомендуемое количество занятий до освоения зоны.
    let recommendedLessonCount: Int
    /// Средняя длительность сессии в минутах.
    let estimatedMinutesPerSession: Int

    init(
        id: String,
        name: String,
        icon: String,
        sounds: [String],
        progress: Float,
        completedLessons: Int,
        totalLessons: Int,
        colorName: String,
        isLocked: Bool,
        position: CGPoint = .zero,
        isCurrentLocation: Bool = false,
        description: String = "",
        prerequisiteZoneId: String? = nil,
        recommendedLessonCount: Int = 20,
        estimatedMinutesPerSession: Int = 12
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.sounds = sounds
        self.progress = progress
        self.completedLessons = completedLessons
        self.totalLessons = totalLessons
        self.colorName = colorName
        self.isLocked = isLocked
        self.position = position
        self.isCurrentLocation = isCurrentLocation
        self.description = description
        self.prerequisiteZoneId = prerequisiteZoneId
        self.recommendedLessonCount = recommendedLessonCount
        self.estimatedMinutesPerSession = estimatedMinutesPerSession
    }
}

// MARK: - View-ready zone card

struct WorldZoneCard: Sendable, Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String
    let soundsLabel: String
    let progress: Double
    let progressLabel: String
    let lessonsLabel: String
    /// Имя цвета из палитры `ColorTokens.Brand.*` (маппинг — на стороне View).
    let colorName: String
    let isLocked: Bool
    let isHighlighted: Bool
    /// Нормализованная позиция острова на канвасе [0..1, 0..1].
    let position: CGPoint
    /// Маркер «текущего» острова на канвасе.
    let isCurrentLocation: Bool
    /// Полностью пройденная зона (>=100%).
    let isCompleted: Bool
    let accessibilityLabel: String
    let accessibilityHint: String
}
