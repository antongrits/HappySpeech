import Foundation

// MARK: - SessionComplete VIP Models
//
// Экран финала сессии. 7-стадийный reward reveal:
//   Stage 1 (.celebration)  — Ляля появляется, анимация
//   Stage 2 (.scoreReveal)  — count-up очки 0 → итог
//   Stage 3 (.stars)        — 3 звезды поочерёдно
//   Stage 4 (.achievement)  — разблокировка достижения (если есть)
//   Stage 5 (.sticker)      — новая наклейка (flip animation)
//   Stage 6 (.streak)       — обновление серии дней
//   Stage 7 (.nextPreview)  — превью следующей сессии + CTA

// MARK: - RewardStage

/// 7 стадий reveal. Используется для прогрессивного раскрытия UI
/// и для snapshot-тестов: можно задать конкретную стадию.
public enum RewardStage: Int, Sendable, CaseIterable, Comparable {
    case celebration = 0
    case scoreReveal
    case stars
    case achievement
    case sticker
    case streak
    case nextPreview

    public static func < (lhs: RewardStage, rhs: RewardStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - SessionCompletePhase (legacy alias for existing views)

/// Стадия анимации reveal — оставлена для совместимости с кодом внутри View.
public typealias SessionCompletePhase = RewardStage

// MARK: - ScoreBreakdown

/// Детальный разбор счёта за сессию.
public struct ScoreBreakdown: Sendable, Equatable {
    /// Итоговый счёт (0–100).
    public let total: Int
    /// Базовый счёт за правильные ответы.
    public let baseScore: Int
    /// Бонус за серию правильных ответов.
    public let streakBonus: Int
    /// Штраф за использованные подсказки (отрицательный).
    public let hintPenalty: Int
    /// Точность в диапазоне 0…1.
    public let accuracy: Float
    /// Количество использованных подсказок.
    public let hintsUsed: Int
    /// Длительность в секундах.
    public let durationSec: Int
    /// Флаг «без единой подсказки».
    public let noHints: Bool

    /// Три звезды: 1 — выполнено, 2 — ≥60%, 3 — ≥85% + noHints.
    public var starsEarned: Int {
        if accuracy >= 0.85 && noHints { return 3 }
        if accuracy >= 0.60 { return 2 }
        return 1
    }
}

// MARK: - SessionResult (DTO from caller)

/// Результат сессии, передаваемый в экран извне (из LessonPlayer / координатора).
/// Чистая Sendable-структура без UI-зависимостей.
public struct SessionResult: Sendable, Equatable {
    public let score: Float          // 0…1 (accuracy)
    public let starsEarned: Int      // 0…3
    public let gameTitle: String
    public let soundTarget: String
    public let attempts: Int
    public let correctAttempts: Int
    public let hintsUsed: Int
    public let durationSec: Int
    public let nextLessonTitle: String?
    public let childId: String
    public let sessionId: String

    /// Итоговый счёт 0–100 с бонусами.
    public var computedScore: Int {
        let base = Int(score * 70)
        let streak = hintsUsed == 0 ? 15 : 0
        let penalty = min(hintsUsed * 3, 20)
        return max(0, min(100, base + streak - penalty))
    }

    /// Полный разбор счёта.
    public var breakdown: ScoreBreakdown {
        let base = Int(score * 70)
        let streakBonus = hintsUsed == 0 ? 15 : 0
        let hintPenalty = min(hintsUsed * 3, 20)
        return ScoreBreakdown(
            total: computedScore,
            baseScore: base,
            streakBonus: streakBonus,
            hintPenalty: -hintPenalty,
            accuracy: score,
            hintsUsed: hintsUsed,
            durationSec: durationSec,
            noHints: hintsUsed == 0
        )
    }

    public init(
        score: Float,
        starsEarned: Int,
        gameTitle: String,
        soundTarget: String,
        attempts: Int,
        correctAttempts: Int = 0,
        hintsUsed: Int = 0,
        durationSec: Int,
        nextLessonTitle: String?,
        childId: String = "",
        sessionId: String = UUID().uuidString
    ) {
        self.score = max(0, min(1, score))
        self.starsEarned = max(0, min(3, starsEarned))
        self.gameTitle = gameTitle
        self.soundTarget = soundTarget
        self.attempts = max(0, attempts)
        self.correctAttempts = max(0, correctAttempts)
        self.hintsUsed = max(0, hintsUsed)
        self.durationSec = max(0, durationSec)
        self.nextLessonTitle = nextLessonTitle
        self.childId = childId
        self.sessionId = sessionId
    }

    /// Демо-данные для preview / навигации с дефолтным результатом.
    public static let sample = SessionResult(
        score: 0.86,
        starsEarned: 3,
        gameTitle: String(localized: "sessionComplete.sample.gameTitle"),
        soundTarget: "Р",
        attempts: 12,
        correctAttempts: 10,
        hintsUsed: 0,
        durationSec: 540,
        nextLessonTitle: String(localized: "sessionComplete.sample.nextTitle"),
        childId: "preview-child",
        sessionId: UUID().uuidString
    )
}

// MARK: - UnlockedAchievementInfo

/// DTO для отображения разблокированного достижения на экране.
public struct UnlockedAchievementInfo: Sendable, Equatable {
    public let title: String
    public let description: String
    public let iconName: String
    public let rarity: String
}

// MARK: - StickerRevealInfo

/// DTO для отображения выданной наклейки.
public struct StickerRevealInfo: Sendable, Equatable {
    public let id: String
    public let emoji: String
    public let name: String
    public let collectionName: String
}

// MARK: - StreakInfo

/// DTO с информацией об обновлённой серии дней.
public struct StreakInfo: Sendable, Equatable {
    public let currentStreak: Int
    public let isMilestone: Bool
    public let milestoneLabel: String?
}

// MARK: - VIP scenes

enum SessionCompleteModels {

    // MARK: - LoadResult

    enum LoadResult {
        struct Request: Sendable {
            let result: SessionResult
        }
        struct Response: Sendable {
            let result: SessionResult
            let breakdown: ScoreBreakdown
        }
        struct ViewModel: Sendable {
            let scoreInt: Int
            let scoreLabel: String
            let starsEarned: Int
            let starsTotal: Int
            let gameTitle: String
            let soundLabel: String
            let attemptsLabel: String
            let correctLabel: String
            let durationLabel: String
            let hintsLabel: String
            let nextLessonTitle: String?
            let mascotTagline: String
            let accessibilitySummary: String
            let isPerfect: Bool
            let showConfetti: Bool
            // Breakdown detail
            let baseScoreLabel: String
            let streakBonusLabel: String
            let hintPenaltyLabel: String
            let totalScoreLabel: String
        }
    }

    // MARK: - AdvanceStage

    enum AdvanceStage {
        struct Request: Sendable {
            let to: RewardStage
        }
        struct Response: Sendable {
            let stage: RewardStage
        }
        struct ViewModel: Sendable {
            let stage: RewardStage
        }
    }

    // MARK: - AdvancePhase (legacy alias for existing View code)

    enum AdvancePhase {
        struct Request: Sendable {
            let to: RewardStage
        }
        struct Response: Sendable {
            let phase: RewardStage
        }
        struct ViewModel: Sendable {
            let phase: RewardStage
        }
    }

    // MARK: - AchievementUnlocked

    enum AchievementUnlocked {
        struct Response: Sendable {
            let achievements: [UnlockedAchievementInfo]
        }
        struct ViewModel: Sendable {
            let achievements: [UnlockedAchievementInfo]
            let hasAchievements: Bool
            let toastMessage: String
        }
    }

    // MARK: - StickerReveal

    enum StickerReveal {
        struct Response: Sendable {
            let sticker: StickerRevealInfo
        }
        struct ViewModel: Sendable {
            let sticker: StickerRevealInfo
            let revealLabel: String
        }
    }

    // MARK: - StreakUpdate

    enum StreakUpdate {
        struct Response: Sendable {
            let streak: StreakInfo
        }
        struct ViewModel: Sendable {
            let streak: StreakInfo
            let streakLabel: String
            let milestoneLabel: String?
            let iconName: String
        }
    }

    // MARK: - ShareResult

    enum ShareResult {
        struct Request: Sendable {}
        struct Response: Sendable {
            let shareText: String
        }
        struct ViewModel: Sendable {
            let shareText: String
        }
    }

    // MARK: - PlayAgain

    enum PlayAgain {
        struct Request: Sendable {}
        struct Response: Sendable {}
        struct ViewModel: Sendable {}
    }

    // MARK: - ProceedToNext

    enum ProceedToNext {
        struct Request: Sendable {}
        struct Response: Sendable {
            let hasNext: Bool
        }
        struct ViewModel: Sendable {
            let hasNext: Bool
        }
    }

    // MARK: - Failure

    enum Failure {
        struct Response: Sendable {
            let message: String
        }
        struct ViewModel: Sendable {
            let toastMessage: String
        }
    }
}
