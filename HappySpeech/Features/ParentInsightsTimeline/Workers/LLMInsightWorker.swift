import Foundation
import OSLog

// MARK: - LLMInsightWorkerProtocol

@MainActor
protocol LLMInsightWorkerProtocol: AnyObject {
    /// Пробует получить короткий комментарий от on-device LLM (Tier A).
    /// При неудаче возвращает `nil` — View покажет эвристический комментарий.
    ///
    /// Контракт COPPA: всегда вызывается из `parent`-контура, никогда из `kid`.
    /// Tier B (внешний HF) не используется на этом экране — детский trail
    /// статистики может содержать имя ребёнка.
    func enrich(insights: [DailyInsight], childName: String) async -> ([DailyInsight], Bool)
}

// MARK: - LLMInsightWorker

@MainActor
final class LLMInsightWorker: LLMInsightWorkerProtocol {

    private let localLLM: any LocalLLMService
    private let maxEnrichedDays: Int = 3   // не более 3 LLM-вызовов за один рефреш

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ParentInsightsTimeline.LLMInsightWorker"
    )

    init(localLLM: any LocalLLMService) {
        self.localLLM = localLLM
    }

    func enrich(insights: [DailyInsight], childName: String) async -> ([DailyInsight], Bool) {
        guard localLLM.isModelDownloaded else {
            Self.logger.debug("LLM model not downloaded — skipping enrichment")
            return (insights, false)
        }

        // Сортируем по «потенциалу полезности»:
        //  • дни с активностью первыми
        //  • а из них берём top-3 по abs(successRate - 0.7) — самые интересные точки.
        let candidates = insights
            .enumerated()
            .filter { $0.element.sessionCount > 0 }
            .sorted { abs($0.element.successRate - 0.7) > abs($1.element.successRate - 0.7) }
            .prefix(maxEnrichedDays)

        var result = insights
        var usedLLM = false

        for (idx, insight) in candidates {
            let request = ParentSummaryRequest(
                childName: childName,
                targetSound: "—",
                stage: "weekly-insight",
                totalAttempts: insight.sessionCount * 8,
                correctAttempts: Int(Double(insight.sessionCount * 8) * insight.successRate),
                errorWords: [],
                sessionDurationSec: insight.minutesPracticed * 60
            )
            do {
                let response = try await localLLM.generateParentSummary(request: request)
                let trimmed = response.parentSummary
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !trimmed.isEmpty {
                    let enriched = DailyInsight(
                        id: insight.id,
                        day: insight.day,
                        weekdayShort: insight.weekdayShort,
                        sessionCount: insight.sessionCount,
                        minutesPracticed: insight.minutesPracticed,
                        successRate: insight.successRate,
                        severity: insight.severity,
                        llmComment: trimmed,
                        isToday: insight.isToday
                    )
                    result[idx] = enriched
                    usedLLM = true
                }
            } catch {
                Self.logger.warning("LLM enrich \(insight.id, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        return (result, usedLLM)
    }
}
