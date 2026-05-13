import Foundation

// MARK: - DailyChallengeModels (Clean Swift: Models)
//
// Block AE batch 2 v21 — ежедневный челлендж: gamification экран для ребёнка.
//
// Сущности фичи:
//   • DailyGoal — цель дня (звуки/повторения/минуты)
//   • StreakState — текущая серия и максимальный рекорд
//   • RewardPreview — что ребёнок получит за выполнение
//
// Persistence: read-only через `SessionRepository` + `ChildRepository`.
// COPPA: всё on-device, рекомендации детерминированные (RuleBased).

// MARK: - DailyGoalKind

/// Тип цели дня. Чередуется день за днём, чтобы не было однообразия.
public enum DailyGoalKind: String, CaseIterable, Sendable, Equatable {
    case repetitions     // «10 повторений»
    case minutes         // «5 минут практики»
    case soundFocus      // «3 раза «С»»
    case streakKeep      // «Не теряй серию!»

    public var titleKey: String {
        switch self {
        case .repetitions: return "dailyChallenge.goal.repetitions.title"
        case .minutes:     return "dailyChallenge.goal.minutes.title"
        case .soundFocus:  return "dailyChallenge.goal.soundFocus.title"
        case .streakKeep:  return "dailyChallenge.goal.streakKeep.title"
        }
    }

    public var symbolName: String {
        switch self {
        case .repetitions: return "repeat.circle.fill"
        case .minutes:     return "timer"
        case .soundFocus:  return "speaker.wave.3.fill"
        case .streakKeep:  return "flame.fill"
        }
    }
}

// MARK: - DailyGoalState

/// Снимок цели на конкретный день.
public struct DailyGoalState: Sendable, Equatable, Identifiable {
    public let id: String          // YYYY-MM-DD + childId
    public let kind: DailyGoalKind
    public let target: Int         // напр. 10 (повторений), 5 (минут), 3 (раз)
    public let current: Int        // прогресс
    public let targetSound: String // «С», «Ш» — null-обрабатывается для не-фонетических целей
    public let isCompleted: Bool

    public init(
        id: String,
        kind: DailyGoalKind,
        target: Int,
        current: Int,
        targetSound: String,
        isCompleted: Bool
    ) {
        self.id = id
        self.kind = kind
        self.target = target
        self.current = current
        self.targetSound = targetSound
        self.isCompleted = isCompleted
    }
}

// MARK: - StreakState

public struct StreakState: Sendable, Equatable {
    public let current: Int
    public let longest: Int
    public let lastSessionISO: String?   // ISO-8601 строкой, чтобы оставаться Sendable
}

// MARK: - RewardPreview

public struct RewardPreview: Sendable, Equatable {
    public let stickerName: String       // имя стикера в Assets
    public let xpAward: Int              // 10/20/30 XP
    public let titleKey: String          // локализованный ключ
}

// MARK: - DailyChallengeModels namespace

enum DailyChallengeModels {

    // MARK: Load

    enum Load {
        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let goal: DailyGoalState
            let streak: StreakState
            let reward: RewardPreview
            let childDisplayName: String
        }

        struct ViewModel: Sendable {
            let goalTitle: String
            let goalSubtitle: String
            let goalSymbol: String
            let goalProgressValue: Double  // 0...1
            let goalProgressLabel: String  // «3 из 10»
            let isCompleted: Bool
            let streakTitle: String        // «Серия: 4 дня»
            let streakAccessibilityLabel: String
            let longestStreakLabel: String
            let rewardTitle: String        // «Получи стикер Звёздочка»
            let rewardSubtitle: String     // «+20 XP»
            let rewardSticker: String      // image name
            let ctaTitle: String           // «В путь!» / «Поделиться»
            let heroSubtitle: String       // «Привет, Маша!»
        }
    }

    // MARK: StartSession

    enum StartSession {
        struct Request: Sendable {
            let childId: String
            let targetSound: String
        }

        struct Response: Sendable {
            let childId: String
            let targetSound: String
        }

        struct ViewModel: Sendable {
            let childId: String
            let targetSound: String
        }
    }

    // MARK: ShareCompletion

    enum ShareCompletion {
        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let snapshotText: String       // что родителю покажется
            let toastKey: String
        }

        struct ViewModel: Sendable {
            let snapshotText: String
            let toastMessage: String
        }
    }
}

// MARK: - DailyChallengeBuilder

/// Утилита для построения цели дня.
///
/// Алгоритм:
///   1. Берём день недели (1...7).
///   2. Маппим на `DailyGoalKind` по фиксированному циклу (Mon=repetitions,
///      Tue=minutes, Wed=soundFocus, Thu=repetitions, Fri=streakKeep,
///      Sat=minutes, Sun=soundFocus).
///   3. Target подбираем по возрасту ребёнка (5-6 = 7 повт / 3 мин,
///      6-7 = 10 повт / 5 мин, 7-8 = 12 повт / 7 мин).
///   4. Reward = sticker из заранее заданного пула.
public enum DailyChallengeBuilder {

    /// Стикеры-награды в фиксированной ротации (имена из Assets.xcassets).
    static let rewardStickers: [String] = [
        "sticker-star", "sticker-rocket", "sticker-balloon",
        "sticker-trophy", "sticker-heart", "sticker-medal", "sticker-rainbow"
    ]

    /// Возвращает kind по дню недели (1=Mon … 7=Sun).
    static func kind(forWeekday weekday: Int) -> DailyGoalKind {
        switch weekday {
        case 2: return .repetitions   // Mon (Foundation Calendar.Mon=2)
        case 3: return .minutes
        case 4: return .soundFocus
        case 5: return .repetitions
        case 6: return .streakKeep
        case 7: return .minutes
        default: return .soundFocus   // Sun (1)
        }
    }

    /// Возвращает target по возрасту и kind.
    static func target(forAge age: Int, kind: DailyGoalKind) -> Int {
        switch (age, kind) {
        case (...6, .repetitions): return 7
        case (7, .repetitions):    return 10
        case (8..., .repetitions): return 12

        case (...6, .minutes): return 3
        case (7, .minutes):    return 5
        case (8..., .minutes): return 7

        case (_, .soundFocus): return 3

        case (_, .streakKeep): return 1
        default: return 10
        }
    }

    /// XP-награда по kind.
    static func xp(forKind kind: DailyGoalKind) -> Int {
        switch kind {
        case .repetitions: return 20
        case .minutes:     return 25
        case .soundFocus:  return 30
        case .streakKeep:  return 15
        }
    }

    /// Стабильная награда на день (детерминированно — sticker зависит от daySeed).
    static func reward(forDaySeed seed: Int, kind: DailyGoalKind) -> RewardPreview {
        let stickerIndex = abs(seed) % rewardStickers.count
        return RewardPreview(
            stickerName: rewardStickers[stickerIndex],
            xpAward: xp(forKind: kind),
            titleKey: "dailyChallenge.reward.\(kind.rawValue).title"
        )
    }

    /// Готовит DailyGoalState из текущего прогресса.
    public static func makeGoal(
        childId: String,
        day: Date,
        weekday: Int,
        age: Int,
        targetSound: String,
        currentProgress: Int
    ) -> DailyGoalState {
        let kind = kind(forWeekday: weekday)
        let target = target(forAge: age, kind: kind)
        let dayKey = ISO8601DateFormatter.dayString(from: day)
        return DailyGoalState(
            id: "\(dayKey)-\(childId)",
            kind: kind,
            target: target,
            current: min(currentProgress, target),
            targetSound: targetSound,
            isCompleted: currentProgress >= target
        )
    }
}

// MARK: - ISO8601 helper

extension ISO8601DateFormatter {
    /// «2026-05-13» — нужный нам ключ для дневной агрегации.
    static func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}
