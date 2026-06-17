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
    ///   - totalAttempts: РЕАЛЬНОЕ суммарное число попыток за период (из агрегата).
    ///     `nil` — данных нет, в LLM-промпт счётчики попыток не передаются.
    ///   - correctAttempts: РЕАЛЬНОЕ число правильных попыток за период.
    func generateInsights(
        childName: String,
        sounds: [SoundProgress],
        streakDays: Int,
        totalAttempts: Int? = nil,
        correctAttempts: Int? = nil
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
            let resolved = resolveAttempts(
                totalAttempts: totalAttempts,
                correctAttempts: correctAttempts,
                sounds: sounds
            )
            if let llmInsights = await tryLLMInsights(
                service: service,
                childName: childName,
                bestStat: bestStat,
                attempts: resolved
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
        attempts: (total: Int, correct: Int)
    ) async -> [ParentInsight]? {
        // В LLM уходят РЕАЛЬНЫЕ счётчики попыток (см. resolveAttempts) — никогда
        // не фиктивный 0 (раньше correctAttempts:0 → LLM мог выдать «точность ~0%»).
        let summaryInput = SessionSummaryInput(
            sessionId: "insights-\(Int(Date().timeIntervalSince1970))",
            childId: "child-default",
            childName: childName,
            age: 6,
            targetSound: bestStat?.sound ?? "—",
            stage: .wordInit,
            totalAttempts: attempts.total,
            correctAttempts: attempts.correct,
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

    // MARK: - Attempts resolution

    /// Возвращает реальные счётчики попыток для LLM-входа.
    /// Приоритет — явные значения из агрегата (totalAttempts/correctAttempts).
    /// Если их нет, реконструируем correct из total и реальной средней точности
    /// по звукам; total в этом случае оценивается как ~один заход на сессию-звук.
    /// Никаких фиктивных нулей: correct согласован с реальной точностью.
    private func resolveAttempts(
        totalAttempts: Int?,
        correctAttempts: Int?,
        sounds: [SoundProgress]
    ) -> (total: Int, correct: Int) {
        if let total = totalAttempts, let correct = correctAttempts, total > 0 {
            return (total, min(correct, total))
        }

        // Реконструкция из реальных данных по звукам.
        let totalSessions = sounds.reduce(0) { $0 + $1.sessions }
        guard totalSessions > 0 else { return (0, 0) }

        // Взвешенная по числу сессий средняя точность (0…1) — реальная метрика.
        let weightedCorrect = sounds.reduce(0.0) { acc, sp in
            acc + Double(sp.accuracy) * Double(sp.sessions)
        }
        let meanAccuracy = weightedCorrect / Double(totalSessions)
        let correct = Int((Double(totalSessions) * meanAccuracy).rounded())
        return (totalSessions, min(correct, totalSessions))
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
