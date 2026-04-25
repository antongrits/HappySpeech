import Foundation

// MARK: - SessionComplete VIP Models
//
// Экран финала сессии. 4-фазный reveal:
//   Phase 1 (.mascot, 0→0.5s)   — маскот появляется (scale 0→1, spring)
//   Phase 2 (.score, 0.5→1.2s)  — count-up accuracy (0→N%)
//   Phase 3 (.stars, 1.2→2.0s)  — 3 звезды появляются последовательно
//   Phase 4 (.summary, 2.0→2.5s) — карточки stat + preview след. урока
//
// Контракт инициализации экрана: View принимает `SessionResult` через init.

// MARK: - Phase

/// Стадия анимации reveal. Используется для прогрессивного раскрытия UI
/// и для тестов: можно задать конкретную фазу и проверить snapshot.
public enum SessionCompletePhase: Int, Sendable, CaseIterable, Comparable {
    case mascot = 0
    case score
    case stars
    case summary

    public static func < (lhs: SessionCompletePhase, rhs: SessionCompletePhase) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - SessionResult (DTO from caller)

/// Результат сессии, передаваемый в экран извне (из LessonPlayer / координатора).
/// Чистая Sendable-структура без UI-зависимостей.
public struct SessionResult: Sendable, Equatable {
    public let score: Float          // 0…1
    public let starsEarned: Int      // 0…3
    public let gameTitle: String
    public let soundTarget: String
    public let attempts: Int
    public let durationSec: Int
    public let nextLessonTitle: String?

    public init(
        score: Float,
        starsEarned: Int,
        gameTitle: String,
        soundTarget: String,
        attempts: Int,
        durationSec: Int,
        nextLessonTitle: String?
    ) {
        self.score = max(0, min(1, score))
        self.starsEarned = max(0, min(3, starsEarned))
        self.gameTitle = gameTitle
        self.soundTarget = soundTarget
        self.attempts = max(0, attempts)
        self.durationSec = max(0, durationSec)
        self.nextLessonTitle = nextLessonTitle
    }

    /// Демо-данные для preview / навигации с дефолтным результатом.
    public static let sample = SessionResult(
        score: 0.86,
        starsEarned: 3,
        gameTitle: String(localized: "sessionComplete.sample.gameTitle"),
        soundTarget: "Р",
        attempts: 12,
        durationSec: 540,
        nextLessonTitle: String(localized: "sessionComplete.sample.nextTitle")
    )
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
        }
        struct ViewModel: Sendable {
            let scoreInt: Int
            let scoreLabel: String
            let starsEarned: Int
            let starsTotal: Int
            let gameTitle: String
            let soundLabel: String
            let attemptsLabel: String
            let durationLabel: String
            let nextLessonTitle: String?
            let mascotTagline: String
            let accessibilitySummary: String
        }
    }

    // MARK: - AdvancePhase

    enum AdvancePhase {
        struct Request: Sendable {
            let to: SessionCompletePhase
        }
        struct Response: Sendable {
            let phase: SessionCompletePhase
        }
        struct ViewModel: Sendable {
            let phase: SessionCompletePhase
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
