import Foundation
import OSLog

// MARK: - InsightAggregatorWorkerProtocol

@MainActor
protocol InsightAggregatorWorkerProtocol: AnyObject {
    /// Берёт сессии ребёнка и аггрегирует по 7 дням, заканчивая в `endingOn`.
    func buildWeek(
        childId: String,
        endingOn date: Date
    ) async -> [DailyInsight]

    /// Подсчитывает суммарную статистику недели.
    func summary(from insights: [DailyInsight]) -> WeeklySummary
}

// MARK: - InsightAggregatorWorker

@MainActor
final class InsightAggregatorWorker: InsightAggregatorWorkerProtocol {

    private let sessionRepository: any SessionRepository
    private let calendar: Calendar

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ParentInsightsTimeline.AggregatorWorker"
    )

    init(
        sessionRepository: any SessionRepository,
        calendar: Calendar = .current
    ) {
        self.sessionRepository = sessionRepository
        self.calendar = calendar
    }

    func buildWeek(
        childId: String,
        endingOn date: Date
    ) async -> [DailyInsight] {
        // Берём с большим запасом, чтобы попасть в недельное окно даже у активных детей.
        let recent: [SessionDTO]
        do {
            recent = try await sessionRepository.fetchRecent(childId: childId, limit: 128)
        } catch {
            Self.logger.error("fetchRecent failed: \(error.localizedDescription, privacy: .public)")
            recent = []
        }

        let template = WeekTimelineBuilder.emptyWeek(endingOn: date, calendar: calendar)
        guard !template.isEmpty else { return [] }

        // Группируем сессии по startOfDay(date).
        let byDayId: [String: [SessionDTO]] = Dictionary(
            grouping: recent,
            by: { ISO8601DateFormatter.dayString(from: calendar.startOfDay(for: $0.date)) }
        )

        return template.map { slot in
            let sessions = byDayId[slot.id] ?? []
            let count = sessions.count
            let totalSeconds = sessions.reduce(0) { $0 + $1.durationSeconds }
            let totalAttempts = sessions.reduce(0) { $0 + $1.totalAttempts }
            let totalCorrect = sessions.reduce(0) { $0 + $1.correctAttempts }
            let successRate: Double = totalAttempts > 0
                ? Double(totalCorrect) / Double(totalAttempts)
                : 0

            let severity = WeekTimelineBuilder.severity(
                sessionCount: count,
                successRate: successRate,
                isToday: slot.isToday
            )

            return DailyInsight(
                id: slot.id,
                day: slot.day,
                weekdayShort: slot.weekdayShort,
                sessionCount: count,
                minutesPracticed: totalSeconds / 60,
                successRate: successRate,
                severity: severity,
                llmComment: nil,    // LLM-комментарий добавляется во второй проход
                isToday: slot.isToday
            )
        }
    }

    func summary(from insights: [DailyInsight]) -> WeeklySummary {
        let totalSessions = insights.reduce(0) { $0 + $1.sessionCount }
        let totalMinutes = insights.reduce(0) { $0 + $1.minutesPracticed }
        let rated = insights.filter { $0.sessionCount > 0 }
        let avgRate: Double = rated.isEmpty
            ? 0
            : rated.reduce(0.0) { $0 + $1.successRate } / Double(rated.count)
        let activeDays = rated.count
        let bestDay = rated.max(by: { $0.successRate < $1.successRate })?.id

        return WeeklySummary(
            totalSessions: totalSessions,
            totalMinutes: totalMinutes,
            averageSuccessRate: avgRate,
            activeDays: activeDays,
            bestDayId: bestDay
        )
    }
}
