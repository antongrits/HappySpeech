import Foundation
import OSLog

// MARK: - NeurolinguistInsightsInteractor
//
// Бизнес-логика «Insights от Ляли»:
//   1. Загружает последние N сессий ребёнка.
//   2. Считает метрики за 7-дневное окно (accuracy, по звукам, по дням).
//   3. Генерирует Russian summary через rule-based template
//      (НЕ настоящий MLX LLM inference — fallback Variant B).
//   4. Кэширует InsightObject в Realm на 24 часа.
//   5. forceRefresh=true игнорирует кэш.
//
// Шаблон-генератор содержит ~12 «слотов»: trend, primarySound, accuracy,
// bestSound, challengingSound, sessions count, days active, recommendation.

@MainActor
final class NeurolinguistInsightsInteractor {

    // MARK: - VIP wiring

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "NeurolinguistInsights")
    weak var presenter: NeurolinguistInsightsPresenter?

    // MARK: - Dependencies

    private let childRepository: any ChildRepository
    private let sessionRepository: any SessionRepository
    private let realmActor: RealmActor

    // MARK: - State

    private var currentChildId: String = ""

    // MARK: - Constants

    private let analysisWindowDays: Int = 7

    // MARK: - Init

    init(
        childRepository: any ChildRepository,
        sessionRepository: any SessionRepository,
        realmActor: RealmActor
    ) {
        self.childRepository = childRepository
        self.sessionRepository = sessionRepository
        self.realmActor = realmActor
    }

    // MARK: - Load

    func load(_ request: NeurolinguistInsights.LoadRequest) async {
        currentChildId = request.childId
        Self.logger.info(
            "Insights: load childId=\(request.childId, privacy: .private) force=\(request.forceRefresh, privacy: .public)"
        )

        // Сначала пытаемся достать кэшированный insight (если не force).
        if !request.forceRefresh,
           let cached = await realmActor.fetchLatestInsight(childId: request.childId),
           Date().timeIntervalSince(cached.generatedAt) < NeurolinguistInsights.cacheTTLSeconds {

            let metrics = await computeMetrics(for: request.childId)
            presenter?.presentLoad(NeurolinguistInsights.LoadResponse(
                insight: cached,
                metricsSnapshot: metrics
            ))
            Self.logger.debug("Insights: served from cache")
            return
        }

        // Иначе — генерируем заново.
        await generateAndPersist(for: request.childId)
    }

    func refresh(_ request: NeurolinguistInsights.RefreshRequest) async {
        await generateAndPersist(for: request.childId)
    }

    // MARK: - Generate

    private func generateAndPersist(for childId: String) async {
        do {
            let child = try? await childRepository.fetch(id: childId)
            let metrics = await computeMetrics(for: childId)

            let summaryText = buildSummaryMarkdown(child: child, metrics: metrics)
            let recommendation = buildRecommendation(metrics: metrics)
            let primarySound = metrics.challengingSound
                ?? metrics.bestSound
                ?? child?.targetSounds.first
                ?? "С"

            let insight = InsightData(
                id: "\(childId)_\(Int(Date().timeIntervalSince1970))",
                childId: childId,
                generatedAt: Date(),
                summaryText: summaryText,
                trendLabel: metrics.trend.rawValue,
                sessionsAnalyzedCount: metrics.sessionsCount,
                primarySoundFocus: primarySound,
                recommendation: recommendation
            )
            await realmActor.persistInsight(insight)
            Self.logger.info(
                "Insights: generated insight sessions=\(metrics.sessionsCount, privacy: .public) trend=\(metrics.trend.rawValue, privacy: .public)"
            )

            presenter?.presentLoad(NeurolinguistInsights.LoadResponse(
                insight: insight,
                metricsSnapshot: metrics
            ))
        }
    }

    // MARK: - Metrics

    private func computeMetrics(for childId: String) async -> NeurolinguistInsights.MetricsSnapshot {
        let allSessions = (try? await sessionRepository.fetchAll(childId: childId)) ?? []

        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let windowStart = calendar.date(
            byAdding: .day, value: -analysisWindowDays, to: now
        ) ?? now

        let recentSessions = allSessions.filter { $0.date >= windowStart && $0.date <= now }

        let totalAttempts = recentSessions.reduce(0) { $0 + $1.totalAttempts }
        let correctAttempts = recentSessions.reduce(0) { $0 + $1.correctAttempts }
        let averageAccuracy = totalAttempts > 0
            ? Double(correctAttempts) / Double(totalAttempts)
            : 0

        // Группировка по звуку.
        var soundAccuracy: [String: (total: Int, correct: Int)] = [:]
        for session in recentSessions where !session.targetSound.isEmpty {
            let key = session.targetSound
            let prev = soundAccuracy[key] ?? (0, 0)
            soundAccuracy[key] = (
                prev.total + session.totalAttempts,
                prev.correct + session.correctAttempts
            )
        }

        let soundRates = soundAccuracy.compactMapValues { tuple -> Double? in
            guard tuple.total > 0 else { return nil }
            return Double(tuple.correct) / Double(tuple.total)
        }

        let bestSound = soundRates.max(by: { $0.value < $1.value })?.key
        let challengingSound = soundRates.min(by: { $0.value < $1.value })?.key

        let totalMinutes = recentSessions.reduce(0) { $0 + $1.durationSeconds } / 60

        // Подсчёт активных дней подряд.
        let activeDayKeys = Set(recentSessions.map { calendar.startOfDay(for: $0.date) })
        var consecutive = 0
        var probe = calendar.startOfDay(for: now)
        while activeDayKeys.contains(probe) {
            consecutive += 1
            probe = calendar.date(byAdding: .day, value: -1, to: probe) ?? probe
        }

        // Trend: разница со средним по предыдущему окну.
        let previousWindowStart = calendar.date(
            byAdding: .day, value: -2 * analysisWindowDays, to: now
        ) ?? now
        let previousSessions = allSessions.filter {
            $0.date >= previousWindowStart && $0.date < windowStart
        }
        let previousTotal = previousSessions.reduce(0) { $0 + $1.totalAttempts }
        let previousCorrect = previousSessions.reduce(0) { $0 + $1.correctAttempts }
        let previousAccuracy = previousTotal > 0
            ? Double(previousCorrect) / Double(previousTotal)
            : 0

        let trend: NeurolinguistInsights.TrendKind
        if recentSessions.count < 2 {
            trend = .insufficientData
        } else {
            let delta = averageAccuracy - previousAccuracy
            if abs(delta) < 0.04 {
                trend = .stable
            } else if delta > 0 {
                trend = .improving
            } else {
                trend = .declining
            }
        }

        return NeurolinguistInsights.MetricsSnapshot(
            sessionsCount: recentSessions.count,
            totalAttempts: totalAttempts,
            averageAccuracy: averageAccuracy,
            bestSound: bestSound,
            challengingSound: challengingSound,
            totalMinutes: totalMinutes,
            consecutiveDays: consecutive,
            trend: trend
        )
    }

    // MARK: - Template engine (rule-based summary)

    private func buildSummaryMarkdown(
        child: ChildProfileDTO?,
        metrics: NeurolinguistInsights.MetricsSnapshot
    ) -> String {
        let name = child?.name ?? String(localized: "insights.fallback.child_name")

        var parts: [String] = []

        // 1. Hook
        switch metrics.trend {
        case .improving:
            parts.append(String(format: String(localized: "insights.hook.improving"), name))
        case .stable:
            parts.append(String(format: String(localized: "insights.hook.stable"), name))
        case .declining:
            parts.append(String(format: String(localized: "insights.hook.declining"), name))
        case .insufficientData:
            parts.append(String(format: String(localized: "insights.hook.no_data"), name))
        }

        // 2. Numbers paragraph
        if metrics.sessionsCount > 0 {
            let accuracyPct = Int((metrics.averageAccuracy * 100).rounded())
            parts.append(String(
                format: String(localized: "insights.body.numbers"),
                metrics.sessionsCount,
                metrics.totalMinutes,
                accuracyPct
            ))
        }

        // 3. Best sound highlight
        if let best = metrics.bestSound {
            parts.append(String(
                format: String(localized: "insights.body.best_sound"),
                best
            ))
        }

        // 4. Challenging sound mention
        if let challenging = metrics.challengingSound,
           challenging != metrics.bestSound {
            parts.append(String(
                format: String(localized: "insights.body.challenging_sound"),
                challenging
            ))
        }

        // 5. Streak / consecutive days
        if metrics.consecutiveDays >= 3 {
            parts.append(String(
                format: String(localized: "insights.body.streak"),
                metrics.consecutiveDays
            ))
        } else if metrics.consecutiveDays == 0 && metrics.sessionsCount > 0 {
            parts.append(String(localized: "insights.body.no_recent"))
        }

        // 6. Closing — Lyalya signature
        parts.append(String(localized: "insights.body.signature"))

        return parts.joined(separator: "\n\n")
    }

    private func buildRecommendation(metrics: NeurolinguistInsights.MetricsSnapshot) -> String {
        switch metrics.trend {
        case .improving:
            if let challenging = metrics.challengingSound {
                return String(
                    format: String(localized: "insights.reco.improving_with_challenging"),
                    challenging
                )
            }
            return String(localized: "insights.reco.improving_general")

        case .stable:
            return String(localized: "insights.reco.stable")

        case .declining:
            return String(localized: "insights.reco.declining")

        case .insufficientData:
            return String(localized: "insights.reco.no_data")
        }
    }
}
