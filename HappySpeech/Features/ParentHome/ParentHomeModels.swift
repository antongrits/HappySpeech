import Foundation

// MARK: - ParentHomeModels (Clean Swift namespace)

enum ParentHomeModels {

    // MARK: Fetch

    // swiftlint:disable nesting
    enum Fetch {
        struct Request: Sendable {
            let preferredChildId: String?
        }

        struct Response: Sendable {
            let childId: String
            let childName: String
            let childAge: Int
            let targetSounds: [String]
            let currentStreak: Int
            let totalSessionMinutes: Int
            let overallRate: Double
            let recentSessions: [SessionData]
            let progressSummary: [String: Double]
            let homeTask: String?
            /// M6.16: Последний результат скрининга, nil — скрининг не пройден.
            let screeningOutcome: ScreeningOutcomeDTO?
            // A.6: Multi-child
            let allChildren: [ChildSummary]
            // A.6: Weekly stats
            let weekSessions: [SessionDTO]
            // A.6: Achievements snapshot
            let achievements: [AchievementItem]
            // A.6: Notifications hub
            let notifications: [NotificationItem]
        }

        struct ViewModel: Sendable {
            let childId: String
            let childName: String
            let childAge: Int
            let targetSoundsText: String
            let greeting: String
            let currentStreak: Int
            let totalSessionMinutes: Int
            let overallRate: Double
            let lastSession: SessionSummary?
            let recentSessions: [SessionSummary]
            let soundProgress: [SoundProgress]
            let homeTask: String?
            let recommendations: [String]
            /// M6.16: Карточка скрининга (nil — скрининг не пройден или не актуален).
            let screeningCard: ScreeningCardViewModel?
            // A.6 additions
            let allChildren: [ChildSummary]
            let weekStats: [DayStat]
            let weeklyInsight: WeeklyInsight?
            let achievements: [AchievementItem]
            let notifications: [NotificationItem]
            let quickActions: [QuickAction]
            let needsSpecialistReview: Bool
            let todaySessionsCount: Int
            let todayMinutes: Int
        }
    }
    // swiftlint:enable nesting

    // MARK: - SwitchChild

    enum SwitchChild {
        struct Request: Sendable {
            let childId: String
        }
    }

    // MARK: - AddChild

    enum AddChild {
        struct Request: Sendable {}
    }

    // MARK: - DeleteChild

    enum DeleteChild {
        struct Request: Sendable {
            let childId: String
        }
    }

    // MARK: - MarkNotificationRead

    enum MarkNotificationRead {
        struct Request: Sendable {
            let notificationId: String
        }
    }

    // MARK: - UpdateNotificationPreference

    enum UpdateNotificationPreference {
        struct Request: Sendable {
            let hour: Int
            let minute: Int
        }
    }

    // MARK: - M6.16: Screening Card

    /// ViewModel для карточки скрининга в ParentHome. Показывается если скрининг пройден.
    struct ScreeningCardViewModel: Sendable, Equatable {
        let completedAtText: String
        let severityText: String
        let problematicSoundsText: String
        let recommendationText: String
        let canRetake: Bool
        /// Цвет-код серьёзности для UI — raw строка для Sendable.
        let severityColorToken: String   // "mild" | "moderate" | "severe"
    }

    // MARK: - Multi-child

    struct ChildSummary: Identifiable, Sendable, Hashable {
        let id: String
        let name: String
        let age: Int
        let avatarStyle: String
        let colorTheme: String
        let currentStreak: Int
        let lastSessionAt: Date?

        var isActive: Bool = false
    }

    // MARK: - Weekly stats

    struct DayStat: Identifiable, Sendable, Hashable {
        var id: String { dayLabel }
        let date: Date
        let minutes: Int
        let accuracy: Double
        let sessionsCount: Int

        var dayLabel: String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateFormat = "EEE"
            return formatter.string(from: date).prefix(2).uppercased()
        }
    }

    enum TrendDirection: Sendable, Hashable {
        case up, down, stable
    }

    struct WeeklyInsight: Sendable {
        let summaryText: String
        let highlights: [String]
        let recommendations: [String]
        let source: InsightSource
    }

    enum InsightSource: Sendable {
        case llm
        case ruleBased
    }

    // MARK: - Achievements

    struct AchievementItem: Identifiable, Sendable, Hashable {
        let id: String
        let icon: String
        let title: String
        let subtitle: String
        let unlockedAt: Date
        let colorToken: String   // "gold" | "primary" | "success" | "warning"
    }

    // MARK: - Notifications hub

    struct NotificationItem: Identifiable, Sendable, Hashable {
        let id: String
        let icon: String
        let title: String
        let body: String
        let kind: NotificationKind
        let date: Date
        var isRead: Bool
    }

    enum NotificationKind: String, Sendable, Hashable {
        case reminder
        case achievement
        case specialistMessage
        case systemInfo
    }

    // MARK: - Quick actions

    struct QuickAction: Identifiable, Sendable, Hashable {
        let id: String
        let icon: String
        let title: String
        let destination: QuickActionDestination
    }

    enum QuickActionDestination: Sendable, Hashable {
        case startLesson(childId: String)
        case exportToSpecialist(childId: String)
        case viewHistory(childId: String)
        case openSettings
    }

    // MARK: Domain data

    struct SessionData: Sendable {
        let id: String
        let date: Date
        let templateType: String
        let targetSound: String
        let durationSeconds: Int
        let totalAttempts: Int
        let correctAttempts: Int
    }

    // MARK: Display models

    struct SessionSummary: Identifiable, Sendable, Hashable {
        let id: String
        let targetSound: String
        let templateName: String
        let dateText: String
        let durationText: String
        let totalAttempts: Int
        let correctAttempts: Int
        let successRate: Double

        var resultText: String { "\(correctAttempts)/\(totalAttempts)" }
    }

    struct SoundProgress: Identifiable, Sendable, Hashable {
        var id: String { sound }
        let sound: String
        let familyName: String
        let currentStage: String
        let overallRate: Double
        let sessions: Int
        let trend: TrendDirection

        init(
            sound: String,
            familyName: String,
            currentStage: String,
            overallRate: Double,
            sessions: Int = 0,
            trend: TrendDirection = .stable
        ) {
            self.sound = sound
            self.familyName = familyName
            self.currentStage = currentStage
            self.overallRate = overallRate
            self.sessions = sessions
            self.trend = trend
        }
    }
}
