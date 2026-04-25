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

        var scoreEmoji: String {
            score >= 0.9 ? "⭐️⭐️⭐️" : score >= 0.7 ? "⭐️⭐️" : "⭐️"
        }
    }

    // MARK: - Achievement

    struct Achievement: Identifiable, Hashable, Sendable {
        let id: String
        let title: String
        let description: String
        let emoji: String
        var isVisible: Bool

        static let placeholder = Achievement(
            id: "first-session",
            title: "Первый урок",
            description: "Поздравляем с первым занятием!",
            emoji: "🎉",
            isVisible: true
        )
    }
}
