import Foundation

// MARK: - WeeklySoundReportModels (Clean Swift: Models)
//
// F-301 v25 — «Итоги недели» для родителя.
//
// Сущности фичи:
//   • TrendArrow — направление недельной динамики звука
//   • SoundCardViewModel — карточка одного целевого звука
//   • WordStat — агрегат по конкретному слову (для раскрытой карточки)
//   • Request/Response/ViewModel — VIP контракты
//
// Persistence: read-only — агрегирует существующие Session (через SessionRepository).
// Offline-first: все данные из Realm, без сети.

// MARK: - TrendArrow

/// Направление недельной динамики успешности звука.
public enum TrendArrow: Sendable, Equatable {
    case up      // Δ > +5%
    case stable  // |Δ| ≤ 5%
    case down    // Δ < -5%

    /// SF Symbol для отображения тренда.
    public var symbolName: String {
        switch self {
        case .up:     return "arrow.up"
        case .stable: return "minus"
        case .down:   return "arrow.down"
        }
    }
}

// MARK: - SoundCardViewModel

/// Карточка одного целевого звука в недельном отчёте.
public struct SoundCardViewModel: Identifiable, Sendable, Equatable {
    public let id: String            // targetSound — «Ш»
    public let soundLabel: String    // «Звук Ш»
    public let successRate: Double   // 0.0–1.0 за текущую неделю
    public let previousRate: Double  // 0.0–1.0 за прошлую неделю
    public let trendArrow: TrendArrow
    public let sessionCount: Int

    public init(
        id: String,
        soundLabel: String,
        successRate: Double,
        previousRate: Double,
        trendArrow: TrendArrow,
        sessionCount: Int
    ) {
        self.id = id
        self.soundLabel = soundLabel
        self.successRate = successRate
        self.previousRate = previousRate
        self.trendArrow = trendArrow
        self.sessionCount = sessionCount
    }
}

// MARK: - WeeklyWordStat

/// Агрегат по конкретному слову — для раскрытой секции карточки звука.
public struct WeeklyWordStat: Identifiable, Sendable, Equatable {
    public let id: String        // word
    public let word: String
    public let successRate: Double
    public let attemptCount: Int

    public init(id: String, word: String, successRate: Double, attemptCount: Int) {
        self.id = id
        self.word = word
        self.successRate = successRate
        self.attemptCount = attemptCount
    }
}

// MARK: - WeeklySoundReportModels namespace

enum WeeklySoundReportModels {

    // MARK: Load

    enum Load {
        struct Request: Sendable {
            let childId: String
            var weekOffset: Int = 0
        }

        struct Response: Sendable {
            let childName: String
            let weekSessions: [SessionDTO]
            let previousWeekSessions: [SessionDTO]
            let targetSounds: [String]
            let weekStart: Date
            let weekEnd: Date
        }

        struct ViewModel: Sendable {
            let summaryLine: String      // «Миша позанимался 5 раз — отличный результат!»
            let dateRangeLabel: String   // «12–18 мая 2026»
            let totalSessions: Int
            let activeDays: Int          // занятых дней из 7
            let activeDaysProgress: Double  // activeDays / 7
            let sounds: [SoundCardViewModel]
            let weekOffset: Int
            let canGoNext: Bool          // weekOffset < 0
        }
    }

    // MARK: SelectSound

    enum SelectSound {
        struct Request: Sendable {
            let soundTarget: String
        }

        struct Response: Sendable {
            let topWords: [WeeklyWordStat]
            let weakWords: [WeeklyWordStat]
            let recommendationKey: String
            let recommendationArgument: String
        }

        struct ViewModel: Sendable, Equatable {
            let soundTarget: String
            let topWordsFormatted: [String]    // «солнце — 95%»
            let weakWordsFormatted: [String]
            let tipText: String
            let hasWords: Bool
        }
    }

    // MARK: Share

    enum Share {
        struct Request: Sendable {}

        struct Response: Sendable {
            let summaryLine: String
            let dateRangeLabel: String
            let sounds: [SoundCardViewModel]
        }

        struct ViewModel: Sendable {
            let shareText: String
        }
    }
}
