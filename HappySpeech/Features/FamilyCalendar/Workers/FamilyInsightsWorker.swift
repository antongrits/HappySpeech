import Foundation
import OSLog

// MARK: - FamilyInsightsWorker
//
// Генерирует insight-пункты по статистике семьи.
// Первичная логика: rule-based (Tier C) — всегда работает оффлайн.
// Дополнительно вызывает LLMDecisionService.generateParentTip (Tier B, parent circuit).
// Kid circuit НИКОГДА не попадает в этот worker (только parent).

struct FamilyInsightsWorker {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "FamilyInsightsWorker")

    // MARK: - Rule-Based Insights (Tier C fallback, always available)

    func generateRuleBasedInsights(
        aggregations: [FamilyStatsAggregation],
        selectedChildId: String?
    ) -> [InsightItem] {
        var insights: [InsightItem] = []

        let relevantAggregations: [FamilyStatsAggregation]
        if let childId = selectedChildId {
            relevantAggregations = aggregations.filter { $0.childId == childId }
        } else {
            relevantAggregations = aggregations.filter { $0.childId != "all" }
        }

        // Правило 1: streak >= 5 → «Отличный темп!»
        for agg in relevantAggregations where agg.streak >= 5 {
            insights.append(InsightItem(
                iconName: "flame.fill",
                text: String(format: String(localized: "family_calendar.streak.format"), agg.childName, agg.streak)
            ))
        }

        // Правило 2: Лучший звук с высокой точностью (>= 85%)
        for agg in relevantAggregations {
            if let sound = agg.bestSound, agg.bestSoundRate >= 0.85 {
                let pct = Int(agg.bestSoundRate * 100)
                insights.append(InsightItem(
                    iconName: "star.fill",
                    text: String(format: String(localized: "family_calendar.insight.best_sound"), agg.childName, sound, pct)
                ))
            }
        }

        // Правило 3: Нет сессий за последние 7 дней → напоминание
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        for agg in relevantAggregations {
            let recentDays = agg.dayActivities.keys.filter { $0 >= sevenDaysAgo }
            if recentDays.isEmpty {
                insights.append(InsightItem(
                    iconName: "lightbulb.fill",
                    text: String(localized: "family_calendar.insight.no_recent")
                ))
                break  // один раз достаточно
            }
        }

        // Правило 4: Сегодня уже играл
        let today = calendar.startOfDay(for: Date())
        for agg in relevantAggregations {
            if (agg.dayActivities[today] ?? 0) > 0 {
                insights.append(InsightItem(
                    iconName: "checkmark.seal.fill",
                    text: String(format: String(localized: "family_calendar.insight.played_today"), agg.childName)
                ))
            }
        }

        // Правило 5: Высокий суммарный прогресс
        for agg in relevantAggregations where agg.avgSuccessRate >= 0.9 {
            insights.append(InsightItem(
                iconName: "trophy.fill",
                text: String(format: String(localized: "family_calendar.insight.high_accuracy"), agg.childName, Int(agg.avgSuccessRate * 100))
            ))
        }

        // Гарантированный минимум 1 insight
        if insights.isEmpty {
            insights.append(InsightItem(
                iconName: "lightbulb.fill",
                text: String(localized: "family_calendar.insight.start_today")
            ))
        }

        // Максимум 5 insights
        return Array(insights.prefix(5))
    }

    // MARK: - LLM-Enhanced Insights (Tier B, parent circuit)

    func generateLLMInsights(
        llmService: any LLMDecisionServiceProtocol,
        child: ChildProfileDTO,
        sessions: [SessionDTO]
    ) async -> [InsightItem] {
        let profile = ChildProfileInput(
            id: child.id,
            name: child.name,
            age: child.age,
            targetSounds: child.targetSounds,
            sensitivityLevel: child.sensitivityLevel,
            progressSummary: child.progressSummary
        )
        let currentStage = CorrectionStage.isolated  // fallback stage для агрегированного view

        let outcome = await llmService.generateParentTip(profile: profile, currentStage: currentStage)

        logger.debug("LLM insights source: \(outcome.meta.source.rawValue)")

        var result: [InsightItem] = []
        if !outcome.tip.isEmpty {
            result.append(InsightItem(iconName: "lightbulb.fill", text: outcome.tip))
        }
        if !outcome.exerciseSuggestion.isEmpty {
            result.append(InsightItem(iconName: "figure.mind.and.body", text: outcome.exerciseSuggestion))
        }
        return result
    }
}
