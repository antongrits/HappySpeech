import Foundation
import SwiftUI

// MARK: - DailyStreakModels (Clean Swift: Models)
//
// Block S.1 v16 — Daily Streak Rewards (gamification).
//
// Сущности фичи:
//   • Milestone — этап стрика (3/7/14/30/60/100 дней) с наградой
//   • StreakStatus — текущее состояние стрика (active / broken / saved)
//   • StreakSaverState — заморожен ли «спасатель» в этом месяце
//   • Request/Response/ViewModel — VIP контракты
//
// Persistence: UserDefaults (см. Block I GuidedTour pattern). НЕ Realm —
// чтобы избежать миграций. Ключи под префиксом "happyspeech.dailyStreak.".

// MARK: - DailyStreakMilestone

/// Этап стрика. Каждый milestone разблокируется при достижении `days` подряд
/// активных сессий и одарывает ребёнка иконкой + фразой Ляли.
struct DailyStreakMilestone: Identifiable, Hashable, Sendable {

    let id: String
    let days: Int
    let titleKey: String
    let lyalyaPhraseKey: String
    let symbolName: String

    /// Все доступные milestones, отсортированные по возрастанию.
    static let all: [DailyStreakMilestone] = [
        .init(id: "streak.3",   days: 3,
              titleKey: "streak.milestone.3.title",
              lyalyaPhraseKey: "streak.milestone.3.phrase",
              symbolName: "flame"),
        .init(id: "streak.7",   days: 7,
              titleKey: "streak.milestone.7.title",
              lyalyaPhraseKey: "streak.milestone.7.phrase",
              symbolName: "flame.fill"),
        .init(id: "streak.14",  days: 14,
              titleKey: "streak.milestone.14.title",
              lyalyaPhraseKey: "streak.milestone.14.phrase",
              symbolName: "star.fill"),
        .init(id: "streak.30",  days: 30,
              titleKey: "streak.milestone.30.title",
              lyalyaPhraseKey: "streak.milestone.30.phrase",
              symbolName: "rosette"),
        .init(id: "streak.60",  days: 60,
              titleKey: "streak.milestone.60.title",
              lyalyaPhraseKey: "streak.milestone.60.phrase",
              symbolName: "crown.fill"),
        .init(id: "streak.100", days: 100,
              titleKey: "streak.milestone.100.title",
              lyalyaPhraseKey: "streak.milestone.100.phrase",
              symbolName: "trophy.fill")
    ]

    /// Следующий milestone после `days`, или `nil` если все взяты.
    static func next(after days: Int) -> DailyStreakMilestone? {
        all.first { $0.days > days }
    }

    /// Уже разблокированные.
    static func unlocked(for days: Int) -> [DailyStreakMilestone] {
        all.filter { $0.days <= days }
    }
}

// MARK: - DailyStreakStatus

/// Текущее состояние ежедневной серии.
enum DailyStreakStatus: String, Sendable {
    case fresh         // первый запуск или 0 дней
    case active        // зашёл сегодня, серия идёт
    case pendingToday  // не зашёл сегодня, но вчера был — есть до полуночи
    case broken        // разница >1 день, сброшен
    case saved         // был под угрозой, восстановлен Streak Saver-ом
}

// MARK: - StreakSaverState

/// Состояние «спасателя серии» — раз в календарный месяц можно восстановить
/// упущенный день. Хранится last-used дата.
struct StreakSaverState: Sendable, Equatable {
    let lastUsedAt: Date?
    let availableThisMonth: Bool
}

// MARK: - DailyStreakModels namespace (VIP contracts)

enum DailyStreakModels {

    // MARK: Load

    enum Load {

        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let currentStreak: Int
            let longestStreak: Int
            let status: DailyStreakStatus
            let saver: StreakSaverState
            let unlockedMilestones: [DailyStreakMilestone]
            let nextMilestone: DailyStreakMilestone?
            let lastActiveAt: Date?
        }

        struct ViewModel: Sendable {
            let currentStreak: Int
            let longestStreak: Int
            let statusLabel: String
            let statusEmoji: String
            let progressToNext: Double      // 0.0 — 1.0
            let nextMilestoneTitle: String?
            let nextMilestoneDays: Int?
            let unlockedCount: Int
            let totalMilestones: Int
            let saverAvailable: Bool
            let saverHintLabel: String
            let milestones: [MilestoneRow]
        }

        struct MilestoneRow: Identifiable, Sendable {
            let id: String
            let title: String
            let days: Int
            let symbolName: String
            let isUnlocked: Bool
            let accessibilityLabel: String
        }
    }

    // MARK: CheckIn

    enum CheckIn {
        struct Request: Sendable {
            let childId: String
            let now: Date
        }

        struct Response: Sendable {
            let newStreak: Int
            let unlockedMilestone: DailyStreakMilestone?
            let status: DailyStreakStatus
        }

        struct ViewModel: Sendable {
            let toastMessage: String
            let celebrate: Bool
            let unlockedMilestoneTitle: String?
        }
    }

    // MARK: UseSaver

    enum UseSaver {
        struct Request: Sendable {
            let childId: String
            let now: Date
        }

        struct Response: Sendable {
            let success: Bool
            let restoredStreak: Int
            let nextSaverAvailableAt: Date?
        }

        struct ViewModel: Sendable {
            let bannerMessage: String
            let success: Bool
        }
    }
}
