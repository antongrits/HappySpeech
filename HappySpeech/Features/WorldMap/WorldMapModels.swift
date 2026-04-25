import Foundation
import SwiftUI

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
        }

        struct Response: Sendable {
            let zones: [WorldZone]
            let totalStars: Int
            let highlightedZoneId: String?
            let dailyStreak: Int
        }

        struct ViewModel: Sendable {
            let zones: [WorldZoneCard]
            let highlightedZoneId: String?
            let totalStarsLabel: String
            let totalProgressFraction: Double
            let streakLabel: String
            let hasStreak: Bool
            let summaryAccessibilityLabel: String
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

    // MARK: - Failure

    enum Failure {
        struct Response: Sendable { let message: String }
        struct ViewModel: Sendable { let toastMessage: String }
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
    let backgroundColor: Color
    let foregroundColor: Color
    let isLocked: Bool
    let isHighlighted: Bool
    let accessibilityLabel: String
    let accessibilityHint: String
}
