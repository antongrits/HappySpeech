import Foundation
import OSLog

// MARK: - WeeklySummaryWorker
//
// Собирает недельную статистику из массива SessionDTO.
// Используется в ParentHomeInteractor для секции "На неделе".
// Tier B: пробует LLM generateWeeklyReport → Tier C rule-based при недоступности.

@MainActor
final class WeeklySummaryWorker {

    // MARK: Dependencies

    private let llmService: (any LLMDecisionServiceProtocol)?
    private let logger = Logger(subsystem: "ru.happyspeech", category: "WeeklySummaryWorker")

    // MARK: Init

    init(llmService: (any LLMDecisionServiceProtocol)?) {
        self.llmService = llmService
    }

    // MARK: Public API

    /// Строит [DayStat] за последние 7 дней из всех сессий ребёнка.
    func buildWeekStats(sessions: [SessionDTO], now: Date = Date()) -> [ParentHomeModels.DayStat] {
        let calendar = Calendar.current
        return (0..<7).map { daysAgo -> ParentHomeModels.DayStat in
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: now) else {
                return ParentHomeModels.DayStat(date: now, minutes: 0, accuracy: 0, sessionsCount: 0)
            }
            let daySessions = sessions.filter { calendar.isDate($0.date, inSameDayAs: day) }
            let totalSec = daySessions.reduce(0) { $0 + $1.durationSeconds }
            let avgAccuracy = daySessions.isEmpty ? 0.0 : daySessions.map(\.successRate).reduce(0, +) / Double(daySessions.count)
            return ParentHomeModels.DayStat(
                date: day,
                minutes: totalSec / 60,
                accuracy: avgAccuracy,
                sessionsCount: daySessions.count
            )
        }.reversed()
    }

    /// Вычисляет тренд точности: сравниваем первые 3 дня vs последние 3 дня недели.
    func weekTrend(from dayStat: [ParentHomeModels.DayStat]) -> ParentHomeModels.TrendDirection {
        let activeDays = dayStat.filter { $0.sessionsCount > 0 }
        guard activeDays.count >= 2 else { return .stable }
        let half = activeDays.count / 2
        let firstHalf = activeDays.prefix(half).map(\.accuracy)
        let secondHalf = activeDays.suffix(half).map(\.accuracy)
        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)
        let delta = secondAvg - firstAvg
        if delta > 0.05 { return .up }
        if delta < -0.05 { return .down }
        return .stable
    }

    /// Генерирует LLM-powered insights (Tier B) или rule-based (Tier C).
    /// Parent circuit — Tier B разрешён.
    func generateWeeklyInsight(
        childName: String,
        sessions: [SessionDTO],
        dayStat: [ParentHomeModels.DayStat]
    ) async -> ParentHomeModels.WeeklyInsight {
        let totalSessions = sessions.count
        let avgAccuracy = sessions.isEmpty ? 0.0 : sessions.map(\.successRate).reduce(0, +) / Double(sessions.count)
        let activeDaysCount = dayStat.filter { $0.sessionsCount > 0 }.count

        // Tier B — пробуем LLM
        if let service = llmService {
            if let insight = await tryLLMInsight(
                service: service,
                childName: childName,
                sessions: sessions,
                avgAccuracy: avgAccuracy
            ) {
                return insight
            }
        }

        // Tier C — rule-based
        return ruleBasedInsight(
            childName: childName,
            totalSessions: totalSessions,
            avgAccuracy: avgAccuracy,
            activeDaysCount: activeDaysCount
        )
    }

    // MARK: Private

    private func tryLLMInsight(
        service: any LLMDecisionServiceProtocol,
        childName: String,
        sessions: [SessionDTO],
        avgAccuracy: Double
    ) async -> ParentHomeModels.WeeklyInsight? {
        let soundsPracticed = Array(Set(sessions.map(\.targetSound)))
        let weekInput = WeekSummaryInput(
            weekNumber: Calendar.current.component(.weekOfYear, from: Date()),
            sessionsCount: sessions.count,
            averageScore: avgAccuracy,
            soundsPracticed: soundsPracticed,
            improvementDelta: 0.0
        )
        let outcome = await service.generateWeeklyReport(weeks: [weekInput])
        guard !outcome.meta.usedFallback,
              outcome.meta.source != .ruleBased,
              !outcome.summary.isEmpty else { return nil }

        logger.info("WeeklySummaryWorker: LLM Tier B insight generated")
        return ParentHomeModels.WeeklyInsight(
            summaryText: outcome.summary,
            highlights: outcome.highlights,
            recommendations: outcome.recommendations,
            source: .llm
        )
    }

    private func ruleBasedInsight(
        childName: String,
        totalSessions: Int,
        avgAccuracy: Double,
        activeDaysCount: Int
    ) -> ParentHomeModels.WeeklyInsight {
        let summaryText: String
        let highlights: [String]
        let recommendations: [String]

        switch avgAccuracy {
        case 0.85...:
            summaryText = String(
                format: String(localized: "parent.weekly.summary.excellent"),
                childName,
                totalSessions
            )
            highlights = [
                String(format: String(localized: "parent.weekly.highlight.accuracy"), Int(avgAccuracy * 100)),
                String(format: String(localized: "parent.weekly.highlight.sessions"), totalSessions)
            ]
            recommendations = [String(localized: "parent.weekly.reco.excellent")]
        case 0.60..<0.85:
            summaryText = String(
                format: String(localized: "parent.weekly.summary.good"),
                childName,
                totalSessions
            )
            highlights = [
                String(format: String(localized: "parent.weekly.highlight.accuracy"), Int(avgAccuracy * 100))
            ]
            recommendations = [String(localized: "parent.weekly.reco.good")]
        default:
            summaryText = String(
                format: String(localized: "parent.weekly.summary.needs_work"),
                childName
            )
            highlights = []
            recommendations = [String(localized: "parent.weekly.reco.needs_work")]
        }

        logger.info("WeeklySummaryWorker: rule-based Tier C insight generated")
        return ParentHomeModels.WeeklyInsight(
            summaryText: summaryText,
            highlights: highlights,
            recommendations: recommendations,
            source: .ruleBased
        )
    }
}
