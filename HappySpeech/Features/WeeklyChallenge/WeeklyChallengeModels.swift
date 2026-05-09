import Foundation

// MARK: - WeeklyChallengeModels (Clean Swift: Models)
//
// Block R.3 v18 — Weekly Challenge Screen (gamification).
//
// Сущности фичи:
//   • WeeklyChallengeKind — тип челленджа (sound-streak / lesson-count / time-based)
//   • WeeklyChallengeState — прогресс по 7 дням
//   • DayProgress — состояние одного дня в стрейке челленджа
//   • Request/Response/ViewModel — VIP контракты
//
// Persistence: UserDefaults (per-child + per-week).
// COPPA: всё on-device, никаких сетевых запросов.

// MARK: - WeeklyChallengeKind

/// Тип еженедельного челленджа. Определяет рендер и условия успеха.
public enum WeeklyChallengeKind: String, Sendable, CaseIterable {
    case soundStreak    // 7 дней подряд занятия с целевым звуком
    case lessonCount    // X уроков за неделю
    case mixedTemplates // разные шаблоны игр в неделе
    case bingo          // 7 разных «клеток» бинго
    case storyteller    // прохождение story-completion в каждый день

    public var symbolName: String {
        switch self {
        case .soundStreak:    return "flame.fill"
        case .lessonCount:    return "graduationcap.fill"
        case .mixedTemplates: return "shuffle"
        case .bingo:          return "square.grid.3x3.fill"
        case .storyteller:    return "book.closed.fill"
        }
    }

    public var titleKey: String {
        switch self {
        case .soundStreak:    return "weekly.kind.streak.title"
        case .lessonCount:    return "weekly.kind.count.title"
        case .mixedTemplates: return "weekly.kind.mixed.title"
        case .bingo:          return "weekly.kind.bingo.title"
        case .storyteller:    return "weekly.kind.storyteller.title"
        }
    }

    public var descriptionKey: String {
        switch self {
        case .soundStreak:    return "weekly.kind.streak.description"
        case .lessonCount:    return "weekly.kind.count.description"
        case .mixedTemplates: return "weekly.kind.mixed.description"
        case .bingo:          return "weekly.kind.bingo.description"
        case .storyteller:    return "weekly.kind.storyteller.description"
        }
    }
}

// MARK: - DayProgress

/// Состояние одного дня челленджа.
public enum DayProgress: String, Sendable, Equatable {
    case locked     // ещё не наступил
    case pending    // сегодня, но не выполнено
    case completed  // выполнено
    case missed     // прошёл и не выполнено
}

// MARK: - WeeklyChallengeState

/// Прогресс челленджа на 7 дней.
public struct WeeklyChallengeState: Sendable, Equatable {
    public let kind: WeeklyChallengeKind
    public let weekStart: Date
    public let dayStates: [DayProgress]   // ровно 7 элементов
    public let completed: Int
    public let totalRequired: Int

    public var progress: Double {
        totalRequired > 0
            ? min(Double(completed) / Double(totalRequired), 1.0)
            : 0.0
    }

    public var isCompleted: Bool {
        completed >= totalRequired
    }
}

// MARK: - WeeklyChallengeReward

/// Награда за прохождение.
public struct WeeklyChallengeReward: Identifiable, Sendable {
    public let id: String
    public let titleKey: String
    public let symbolName: String
    public let isUnlocked: Bool
}

// MARK: - WeeklyChallengeModels namespace

enum WeeklyChallengeModels {

    // MARK: Load

    enum Load {

        struct Request: Sendable {
            let childId: String
            let now: Date
        }

        struct Response: Sendable {
            let state: WeeklyChallengeState
            let reward: WeeklyChallengeReward
            let daysUntilEndOfWeek: Int
        }

        struct ViewModel: Sendable {
            let challengeTitle: String
            let challengeDescription: String
            let symbolName: String
            let progressLabel: String         // «3/7»
            let progress: Double              // 0..1
            let progressPercentLabel: String  // «43%»
            let dayCells: [DayCellViewModel]
            let endOfWeekLabel: String
            let rewardTitle: String
            let rewardSymbol: String
            let rewardUnlocked: Bool
            let isCompleted: Bool
        }

        struct DayCellViewModel: Identifiable, Sendable {
            let id: Int           // 0..6
            let dayLabel: String  // «Пн», «Вт» ...
            let progress: DayProgress
            let symbolName: String
            let accessibilityLabel: String
        }
    }

    // MARK: MarkDay

    enum MarkDay {
        struct Request: Sendable {
            let childId: String
            let dayIndex: Int
            let now: Date
        }

        struct Response: Sendable {
            let updatedState: WeeklyChallengeState
            let unlockedReward: Bool
        }

        struct ViewModel: Sendable {
            let toastMessage: String
            let celebrate: Bool
        }
    }

    // MARK: SwitchKind

    enum SwitchKind {
        struct Request: Sendable {
            let childId: String
            let kind: WeeklyChallengeKind
            let now: Date
        }

        struct Response: Sendable {
            let newState: WeeklyChallengeState
        }

        struct ViewModel: Sendable {
            let toastMessage: String
        }
    }
}
