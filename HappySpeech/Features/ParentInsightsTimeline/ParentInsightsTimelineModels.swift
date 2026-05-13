import Foundation

// MARK: - ParentInsightsTimelineModels (Clean Swift: Models)
//
// Block AE batch 2 v21 — weekly LLM insights timeline для родителя.
//
// Цель экрана: показать родителю «карту прогресса за неделю» — 7 дней,
// каждый — короткое insight-сообщение от LLM-аналитики или эвристическое
// (rule-based) при отсутствии Tier B.
//
// Источники данных:
//   • SessionRepository → суммарная активность по дням
//   • LLMDecisionService → опциональный narrative insight (Tier B, parent only)
//
// COPPA: ребёнок-контур никогда не вызывает LLM Tier B.

// MARK: - InsightSeverity

public enum InsightSeverity: String, CaseIterable, Sendable, Equatable {
    case positive
    case neutral
    case attention   // мягко указываем на пропущенный день / низкую активность

    public var symbolName: String {
        switch self {
        case .positive:  return "checkmark.seal.fill"
        case .neutral:   return "circle.dashed"
        case .attention: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - DailyInsight

/// Один день в timeline.
public struct DailyInsight: Sendable, Equatable, Identifiable {
    public let id: String              // YYYY-MM-DD
    public let day: Date
    public let weekdayShort: String    // «Пн», «Вт»
    public let sessionCount: Int
    public let minutesPracticed: Int
    public let successRate: Double     // 0...1
    public let severity: InsightSeverity
    public let llmComment: String?     // null → используем эвристический заголовок
    public let isToday: Bool

    public init(
        id: String,
        day: Date,
        weekdayShort: String,
        sessionCount: Int,
        minutesPracticed: Int,
        successRate: Double,
        severity: InsightSeverity,
        llmComment: String?,
        isToday: Bool
    ) {
        self.id = id
        self.day = day
        self.weekdayShort = weekdayShort
        self.sessionCount = sessionCount
        self.minutesPracticed = minutesPracticed
        self.successRate = successRate
        self.severity = severity
        self.llmComment = llmComment
        self.isToday = isToday
    }
}

// MARK: - WeeklySummary

public struct WeeklySummary: Sendable, Equatable {
    public let totalSessions: Int
    public let totalMinutes: Int
    public let averageSuccessRate: Double
    public let activeDays: Int
    public let bestDayId: String?
}

// MARK: - ParentInsightsTimelineModels namespace

enum ParentInsightsTimelineModels {

    // MARK: Load

    enum Load {
        struct Request: Sendable {
            let childId: String
            let weekEndingOn: Date     // обычно сегодня
        }

        struct Response: Sendable {
            let insights: [DailyInsight]
            let summary: WeeklySummary
            let childName: String
            let usedLLM: Bool          // удалось ли получить хотя бы один LLM-комментарий
        }

        struct ViewModel: Sendable {
            let heroTitle: String              // «Неделя Маши»
            let heroSubtitle: String           // диапазон дат
            let summaryStats: [SummaryStat]
            let cells: [DayCellViewModel]
            let llmSourceLabel: String         // «Tier A on-device» / «эвристика»
        }

        struct SummaryStat: Sendable, Identifiable {
            let id: String                // «sessions», «minutes», «successRate», «days»
            let label: String
            let value: String
            let symbolName: String
        }

        struct DayCellViewModel: Sendable, Identifiable, Equatable {
            let id: String                // YYYY-MM-DD
            let weekdayShort: String
            let dateLabel: String         // «13 мая»
            let severitySymbol: String
            let severityColorName: String // «success», «neutral», «warning»
            let metricsLine: String       // «3 сессии · 8 мин · 92%»
            let comment: String           // готовая reading-копия
            let isToday: Bool
            let accessibilityLabel: String
        }
    }

    // MARK: SelectDay

    enum SelectDay {
        struct Request: Sendable {
            let dayId: String
        }

        struct Response: Sendable {
            let insight: DailyInsight
            let detail: String     // расширенный текст
        }

        struct ViewModel: Sendable {
            let titleLabel: String
            let metricsLabel: String
            let detailParagraph: String
            let recommendationLabel: String?
        }
    }

    // MARK: Refresh

    enum Refresh {
        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let success: Bool
            let toastKey: String
        }

        struct ViewModel: Sendable {
            let toastMessage: String
        }
    }
}

// MARK: - WeekTimelineBuilder

/// Утилита для построения 7-дневной timeline на основе сессий.
public enum WeekTimelineBuilder {

    /// Возвращает 7 пустых insight-структур (Пн → Вс), готовых для заполнения метриками.
    public static func emptyWeek(
        endingOn endDate: Date,
        calendar: Calendar = .current
    ) -> [DailyInsight] {
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "ru_RU")
        weekdayFormatter.setLocalizedDateFormatFromTemplate("EEE")

        let today = calendar.startOfDay(for: endDate)
        var result: [DailyInsight] = []

        for offset in (0..<7).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let id = ISO8601DateFormatter.dayString(from: day)
            let isToday = calendar.isDate(day, inSameDayAs: today)
            let weekday = weekdayFormatter.string(from: day)
                .replacingOccurrences(of: ".", with: "")
                .capitalized

            result.append(DailyInsight(
                id: id,
                day: day,
                weekdayShort: weekday,
                sessionCount: 0,
                minutesPracticed: 0,
                successRate: 0,
                severity: .neutral,
                llmComment: nil,
                isToday: isToday
            ))
        }
        return result
    }

    /// Определяет severity по эвристикам.
    ///   • >=2 сессии и successRate >= 0.7 → .positive
    ///   • 0 сессий и не сегодня → .attention
    ///   • иначе → .neutral
    public static func severity(
        sessionCount: Int,
        successRate: Double,
        isToday: Bool
    ) -> InsightSeverity {
        if sessionCount >= 2 && successRate >= 0.7 {
            return .positive
        }
        if sessionCount == 0 && !isToday {
            return .attention
        }
        return .neutral
    }

    /// Эвристический «комментарий» — fallback, если LLM недоступен.
    public static func heuristicComment(
        sessionCount: Int,
        minutes: Int,
        successRate: Double,
        isToday: Bool
    ) -> String {
        if isToday && sessionCount == 0 {
            return String(localized: "parentInsightsTimeline.heuristic.today.empty")
        }
        if sessionCount == 0 {
            return String(localized: "parentInsightsTimeline.heuristic.day.empty")
        }
        if successRate >= 0.85 {
            return String(
                format: String(localized: "parentInsightsTimeline.heuristic.day.great"),
                Int(successRate * 100)
            )
        }
        if successRate >= 0.6 {
            return String(
                format: String(localized: "parentInsightsTimeline.heuristic.day.good"),
                Int(successRate * 100)
            )
        }
        return String(
            format: String(localized: "parentInsightsTimeline.heuristic.day.tryAgain"),
            minutes
        )
    }
}
