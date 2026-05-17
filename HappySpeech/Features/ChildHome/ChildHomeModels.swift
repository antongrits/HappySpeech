import Foundation
import SwiftUI

// MARK: - ChildHome VIP Models

enum ChildHomeModels {

    // MARK: - Fetch

    // swiftlint:disable nesting
    enum Fetch {
        struct Request {
            let childId: String
        }

        struct Response {
            let childName: String
            let currentStreak: Int
            let mascotMood: MascotMood
            let mascotPhrase: String?
            let dailyTargetSound: String
            let dailyStage: String
            let dailyProgress: Double
            let soundProgress: [SoundProgressData]

            // Sprint 8.7 — additional sections
            let quickPlay: [QuickPlayData]
            let worldZones: [WorldZoneData]
            let recentSessions: [RecentSessionData]
            let achievement: AchievementData?
            let dailyMissionDetail: DailyMissionDetailData

            // B13 — deep VIP additions
            let recentRewards: [RecentRewardData]
            let hasOverdueTask: Bool

            // M8.7 v6 — new sections
            let todayWords: [TodayWordData]
            let homeTasks: [HomeTaskPreviewData]
        }

        struct ViewModel {
            let childName: String
            let currentStreak: Int
            let mascotMood: MascotMood
            let mascotPhrase: String?
            let dailyMission: DailyMission
            let soundProgress: [SoundProgressItem]

            // Sprint 8.7 — additional view models
            let quickPlayItems: [QuickPlayItem]
            let worldZones: [WorldZonePreview]
            let recentSessions: [RecentSession]
            let achievement: Achievement?
            let dailyMissionDetail: DailyMissionDetail
            let formattedDate: String
            let isStreakHot: Bool

            // B13 — deep VIP additions
            let recentRewards: [RecentReward]
            let hasOverdueTask: Bool

            // M8.7 v6 — new sections
            let todayWords: [TodayWord]
            let homeTasks: [HomeTaskPreview]
        }
    }
    // swiftlint:enable nesting

    // MARK: - Data transfer (Interactor → Presenter)

    struct SoundProgressData: Sendable {
        let sound: String
        let stageName: String
        let rate: Double
    }

    struct QuickPlayData: Sendable {
        let id: String
        let templateType: String
        let titleKey: String
        let icon: String
        let accent: QuickPlayAccent
        /// Уровень сложности 1…3. Маппится в звёздочки в карточке.
        let difficulty: Int
    }

    /// B13: последняя награда, отображается в секции «Недавние достижения».
    struct RecentRewardData: Sendable {
        let id: String
        let emoji: String
        let titleKey: String
        let earnedAt: Date
    }

    struct WorldZoneData: Sendable {
        let id: String
        let sound: String
        let emoji: String
        let progress: Double
        let family: SoundFamily
    }

    struct RecentSessionData: Sendable {
        let id: String
        let date: Date
        let templateType: String
        let targetSound: String
        let score: Double
    }

    struct AchievementData: Sendable {
        let id: String
        let titleKey: String
        let descriptionKey: String
        let emoji: String
        let isNew: Bool
    }

    struct DailyMissionDetailData: Sendable {
        let id: String
        let titleKey: String
        let descriptionKey: String
        let targetSound: String
        let templateType: String
        let requiredReps: Int
        let completedReps: Int
    }

    // MARK: - Supporting ViewModel types

    struct DailyMission: Hashable {
        let targetSound: String
        let title: String
        let subtitle: String
        let progress: Double

        static let placeholder = DailyMission(
            targetSound: "Р",
            title: "Звук Р в словах",
            subtitle: "Этап 3 · Слова с Р в начале",
            progress: 0.0
        )
    }

    struct DailyMissionDetail: Hashable, Identifiable {
        let id: String
        let title: String
        let description: String
        let targetSound: String
        let templateType: String
        let requiredReps: Int
        let completedReps: Int

        var progress: Float {
            Float(completedReps) / Float(max(requiredReps, 1))
        }

        var isCompleted: Bool {
            completedReps >= requiredReps
        }

        var repsCounterText: String {
            "\(completedReps) / \(requiredReps)"
        }

        static let placeholder = DailyMissionDetail(
            id: "placeholder-mission",
            title: "Произнеси звук Р в 5 словах",
            description: "Любимая миссия дня",
            targetSound: "Р",
            templateType: TemplateType.repeatAfterModel.rawValue,
            requiredReps: 5,
            completedReps: 0
        )
    }

    struct SoundProgressItem: Identifiable, Hashable {
        var id: String { sound }
        let sound: String
        let stageName: String
        let rate: Double
        let accent: SoundFamily
    }

    // MARK: - Quick Play

    /// Цветовой акцент тайла. Маппится в Color через `ColorTokens` в самой View.
    enum QuickPlayAccent: String, Sendable, Hashable, CaseIterable {
        case coral, mint, sky, butter, lilac, gold, rose
    }

    struct QuickPlayItem: Identifiable, Hashable, Sendable {
        let id: String
        let templateType: String
        let title: String
        let icon: String
        let accent: QuickPlayAccent
        /// 1…3 — рисуется звёздочками в карточке (B13).
        let difficulty: Int
    }

    // MARK: - Recent rewards (B13 — отдельная секция «Недавние достижения»)

    struct RecentReward: Identifiable, Hashable, Sendable {
        let id: String
        let emoji: String
        let title: String
        let earnedAt: Date

        // Block D v16: emoji теперь хранит SF Symbol name (UI chrome).
        static let placeholder = RecentReward(
            id: "placeholder-reward",
            emoji: "medal.fill",
            title: String(localized: "child.home.rewards.placeholder.title"),
            earnedAt: Date()
        )
    }

    // MARK: - World Map mini preview

    struct WorldZonePreview: Identifiable, Hashable, Sendable {
        let id: String
        let sound: String
        let emoji: String
        let progress: Double
        let family: SoundFamily

        var progressPercent: Int { Int((progress * 100).rounded()) }
    }

    // MARK: - Recent sessions

    struct RecentSession: Identifiable, Hashable, Sendable {
        let id: String
        let date: Date
        let gameTitle: String
        let soundTarget: String
        let score: Float

        /// Количество звёзд (1-3) для отрисовки рейтинга через SF Symbol star.fill.
        /// Block D v16: заменили эмодзи "⭐️⭐️⭐️" на числовое представление.
        var scoreStars: Int {
            score >= 0.9 ? 3 : score >= 0.7 ? 2 : 1
        }
    }

    // MARK: - Achievement

    struct Achievement: Identifiable, Hashable, Sendable {
        let id: String
        let title: String
        let description: String
        let emoji: String
        var isVisible: Bool

        // Block D v16: emoji теперь хранит SF Symbol name (UI chrome).
        static let placeholder = Achievement(
            id: "first-session",
            title: String(localized: "child.home.achievement.placeholder.title"),
            description: String(localized: "child.home.achievement.placeholder.description"),
            emoji: "party.popper.fill",
            isVisible: true
        )
    }

    // MARK: - TodayWord (слова из daily route)

    /// Слово дня: показывается ребёнку в карточке «Слова дня».
    struct TodayWord: Identifiable, Hashable, Sendable {
        let id: String
        /// Текст слова (напр. «рыба»).
        let word: String
        /// Транскрипция / слоговое разбиение (напр. «ры-ба»).
        let syllables: String
        /// Целевой звук, который тренируется в этом слове.
        let targetSound: String
        /// Позиция звука в слове: "init" / "mid" / "final".
        let soundPosition: String
        /// Процент правильных попыток ребёнка (0…1). nil → ещё не пробовал.
        let successRate: Double?

        /// Block D v16: позиционные эмодзи заменены на SF Symbol names.
        var positionSymbol: String {
            switch soundPosition {
            case "init":  return "arrow.left"
            case "mid":   return "arrow.left.arrow.right"
            case "final": return "arrow.right"
            default:      return "textformat"
            }
        }
    }

    struct TodayWordData: Sendable {
        let id: String
        let word: String
        let syllables: String
        let targetSound: String
        let soundPosition: String
        let successRate: Double?
    }

    // MARK: - HomeTaskPreview (задание от логопеда)

    /// Краткий preview задания логопеда для секции на ChildHome.
    struct HomeTaskPreview: Identifiable, Hashable, Sendable {
        let id: String
        let title: String
        let targetSound: String
        let dueDate: Date?
        let isCompleted: Bool

        var isOverdue: Bool {
            guard let due = dueDate else { return false }
            return !isCompleted && due < Date()
        }
    }

    struct HomeTaskPreviewData: Sendable {
        let id: String
        let titleKey: String
        /// Количество заданий по звуку — подставляется в `%d` plural-строки `titleKey`.
        let taskCount: Int
        let targetSound: String
        let dueDate: Date?
        let isCompleted: Bool
    }
}
