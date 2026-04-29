import Foundation
import OSLog

// MARK: - ParentInsight

struct ParentInsight: Identifiable, Sendable {
    let id: UUID
    let icon: String
    let tone: InsightTone
    let text: String

    init(icon: String, tone: InsightTone, text: String) {
        self.id = UUID()
        self.icon = icon
        self.tone = tone
        self.text = text
    }
}

// MARK: - InsightTone

enum InsightTone: Sendable {
    case positive
    case neutral
    case warning
}

// MARK: - PerSoundStat (internal)

private struct PerSoundStat {
    let sound: String
    let accuracy: Double
    let sessionCount: Int
}

// MARK: - SoundTrend (internal)

private struct SoundTrend {
    let sound: String
    let direction: TrendDirection
    let deltaPercent: Int
}

private enum TrendDirection {
    case improving
    case declining
    case stable
}

// MARK: - ParentInsightsWorker

/// Генерирует персональные insights для дашборда родителя.
/// Tier B (LLM generateParentSummary) → если недоступен, Tier C (rule-based).
/// Kid circuit — НЕ использует HF API (контур только parent).
@MainActor
final class ParentInsightsWorker {

    // MARK: - Dependencies

    private let llmService: (any LLMDecisionServiceProtocol)?
    private let logger = Logger(subsystem: "ru.happyspeech", category: "ParentInsightsWorker")

    // MARK: - Init

    init(llmService: (any LLMDecisionServiceProtocol)?) {
        self.llmService = llmService
    }

    // MARK: - Public API

    /// Генерирует [ParentInsight] на основе данных прогресса.
    /// - Parameters:
    ///   - childName: Имя ребёнка (для персонализации текста).
    ///   - sounds: Список прогресса по звукам из дашборда.
    ///   - streakDays: Текущая серия дней.
    func generateInsights(
        childName: String,
        sounds: [SoundProgress],
        streakDays: Int
    ) async -> [ParentInsight] {
        guard !sounds.isEmpty else {
            logger.info("generateInsights: no sounds — returning empty placeholder")
            return [ParentInsight(
                icon: "sparkles",
                tone: .neutral,
                text: String(localized: "insights.keep_practicing")
            )]
        }

        let stats = buildPerSoundStats(sounds: sounds)
        let bestStat = stats.max(by: { $0.accuracy < $1.accuracy })
        let worstStat = stats.min(by: { $0.accuracy < $1.accuracy })
        let trends = buildTrends(sounds: sounds)

        // Tier B — пробуем LLM (parent circuit только)
        if let service = llmService {
            logger.info("generateInsights: attempting LLM Tier B")
            if let llmInsights = await tryLLMInsights(
                service: service,
                childName: childName,
                bestStat: bestStat,
                worstStat: worstStat,
                sounds: sounds
            ) {
                logger.info("generateInsights: LLM succeeded, \(llmInsights.count) insights")
                return llmInsights
            }
        }

        // Tier C — rule-based
        logger.info("generateInsights: using rule-based Tier C")
        return ruleBasedInsights(
            childName: childName,
            bestStat: bestStat,
            worstStat: worstStat,
            trends: trends,
            streakDays: streakDays
        )
    }

    // MARK: - Tier B: LLM

    private func tryLLMInsights(
        service: any LLMDecisionServiceProtocol,
        childName: String,
        bestStat: PerSoundStat?,
        worstStat: PerSoundStat?,
        sounds: [SoundProgress]
    ) async -> [ParentInsight]? {
        let summaryInput = SessionSummaryInput(
            sessionId: "insights-\(Int(Date().timeIntervalSince1970))",
            childId: "child-default",
            childName: childName,
            age: 6,
            targetSound: bestStat?.sound ?? "—",
            stage: .wordInit,
            totalAttempts: sounds.reduce(0) { $0 + $1.sessions },
            correctAttempts: 0,
            errorWords: [],
            durationSec: 0,
            date: Date()
        )

        let outcome = await service.generateParentSummary(session: summaryInput)
        guard !outcome.meta.usedFallback,
              outcome.meta.source != LLMDecisionSource.ruleBased,
              !outcome.summary.summaryText.isEmpty else {
            return nil
        }

        // LLM вернул реальный текст — оборачиваем в единственный insight
        return [ParentInsight(
            icon: "sparkles",
            tone: .neutral,
            text: outcome.summary.summaryText
        )]
    }

    // MARK: - Tier C: Rule-based

    private func ruleBasedInsights(
        childName: String,
        bestStat: PerSoundStat?,
        worstStat: PerSoundStat?,
        trends: [SoundTrend],
        streakDays: Int
    ) -> [ParentInsight] {
        var insights: [ParentInsight] = []

        // 1. Лучший звук
        if let best = bestStat, best.accuracy > 0.80 {
            let text = String(
                format: String(localized: "insights.best_sound"),
                childName,
                best.sound,
                Int(best.accuracy * 100)
            )
            insights.append(ParentInsight(icon: "star.fill", tone: .positive, text: text))
        }

        // 2. Проблемный звук
        if let worst = worstStat, worst.accuracy < 0.50 {
            let text = String(
                format: String(localized: "insights.worst_sound"),
                childName,
                worst.sound,
                Int(worst.accuracy * 100)
            )
            insights.append(ParentInsight(icon: "exclamationmark.triangle.fill", tone: .warning, text: text))
        }

        // 3. Падающий тренд
        if let declining = trends.first(where: { $0.direction == .declining }) {
            let text = String(
                format: String(localized: "insights.declining_trend"),
                declining.sound,
                declining.deltaPercent
            )
            insights.append(ParentInsight(icon: "chart.line.downtrend.xyaxis", tone: .warning, text: text))
        }

        // 4. Растущий тренд
        if let improving = trends.first(where: { $0.direction == .improving }) {
            let text = String(
                format: String(localized: "insights.improving_trend"),
                improving.sound
            )
            insights.append(ParentInsight(icon: "chart.line.uptrend.xyaxis", tone: .positive, text: text))
        }

        // 5. Серия
        if streakDays >= 5 {
            let text = String(
                format: String(localized: "insights.streak_excellent"),
                streakDays
            )
            insights.append(ParentInsight(icon: "flame.fill", tone: .positive, text: text))
        }

        // 6. Default — если ни одно правило не сработало
        if insights.isEmpty {
            insights.append(ParentInsight(
                icon: "sparkles",
                tone: .neutral,
                text: String(localized: "insights.keep_practicing")
            ))
        }

        return insights
    }

    // MARK: - Aggregation

    private func buildPerSoundStats(sounds: [SoundProgress]) -> [PerSoundStat] {
        sounds.map { PerSoundStat(sound: $0.sound, accuracy: Double($0.accuracy), sessionCount: $0.sessions) }
    }

    private func buildTrends(sounds: [SoundProgress]) -> [SoundTrend] {
        sounds.compactMap { sound in
            switch sound.trend {
            case .up:
                return SoundTrend(sound: sound.sound, direction: .improving, deltaPercent: 5)
            case .down:
                return SoundTrend(sound: sound.sound, direction: .declining, deltaPercent: 5)
            case .stable:
                return nil
            }
        }
    }
}
