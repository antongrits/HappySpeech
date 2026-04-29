import Foundation
import OSLog

// MARK: - ProgressDashboardBusinessLogic

@MainActor
protocol ProgressDashboardBusinessLogic: AnyObject {
    func loadDashboard(_ request: ProgressDashboardModels.LoadDashboard.Request)
    func changePeriod(_ request: ProgressDashboardModels.ChangePeriod.Request)
    func loadSoundDetail(_ request: ProgressDashboardModels.LoadSoundDetail.Request)
    func requestLLMSummary(_ request: ProgressDashboardModels.RequestLLMSummary.Request)
    func loadInsights(_ request: ProgressDashboardModels.LoadInsights.Request)
}

// MARK: - ProgressDashboardInteractor

/// Бизнес-логика дашборда прогресса.
///
/// Источник данных в M7.2 — in-memory seed (~70–90% accuracy, 7-дневная
/// история). LLM-сводку запрашиваем у `LLMDecisionService`; если сервис
/// возвращает ошибку или работает медленно — Presenter показывает статичный
/// текст-фолбэк.
@MainActor
final class ProgressDashboardInteractor: ProgressDashboardBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any ProgressDashboardPresentationLogic)?

    private let llmDecisionService: (any LLMDecisionServiceProtocol)?
    private let logger = Logger(subsystem: "ru.happyspeech", category: "ProgressDashboard")
    private lazy var insightsWorker = ParentInsightsWorker(llmService: llmDecisionService)

    // MARK: - State

    private var summary: DashboardSummary = .empty
    private var dailyAccuracy: [DailyAccuracy] = []
    private var weeklyAccuracy: [WeeklyAccuracy] = []
    private var sounds: [SoundProgress] = []
    private var soundHistory: [String: [DailyAccuracy]] = [:]
    private var recommendations: [String] = []
    private var currentPeriod: ProgressDashboardModels.TimePeriod = .week
    private var lastChildId: String = "child-default"

    // MARK: - Init

    init(llmDecisionService: (any LLMDecisionServiceProtocol)? = nil) {
        self.llmDecisionService = llmDecisionService
    }

    // MARK: - BusinessLogic

    func loadDashboard(_ request: ProgressDashboardModels.LoadDashboard.Request) {
        logger.info(
            "loadDashboard child=\(request.childId, privacy: .private(mask: .hash)) period=\(request.period.rawValue, privacy: .public)"
        )
        lastChildId = request.childId
        currentPeriod = request.period

        let seed = Self.makeSeed(period: request.period)
        summary = seed.summary
        dailyAccuracy = seed.daily
        weeklyAccuracy = seed.weekly
        sounds = seed.sounds
        soundHistory = seed.soundHistory
        recommendations = seed.recommendations

        let response = ProgressDashboardModels.LoadDashboard.Response(
            summary: summary,
            dailyAccuracy: dailyAccuracy,
            weeklyAccuracy: weeklyAccuracy,
            sounds: sounds,
            recommendations: recommendations,
            period: currentPeriod
        )
        presenter?.presentLoadDashboard(response)
    }

    func changePeriod(_ request: ProgressDashboardModels.ChangePeriod.Request) {
        logger.info("changePeriod period=\(request.period.rawValue, privacy: .public)")
        loadDashboard(.init(childId: request.childId, forceReload: true, period: request.period))
    }

    func loadSoundDetail(_ request: ProgressDashboardModels.LoadSoundDetail.Request) {
        guard let progress = sounds.first(where: { $0.sound == request.sound }) else {
            logger.warning("loadSoundDetail: not found sound=\(request.sound, privacy: .public)")
            presenter?.presentFailure(.init(
                message: String(localized: "progressDashboard.error.soundNotFound")
            ))
            return
        }
        let history = soundHistory[request.sound] ?? dailyAccuracy

        let response = ProgressDashboardModels.LoadSoundDetail.Response(
            progress: progress,
            history: history
        )
        presenter?.presentLoadSoundDetail(response)
    }

    func loadInsights(_ request: ProgressDashboardModels.LoadInsights.Request) {
        logger.info("loadInsights childName=\(request.childName, privacy: .private(mask: .hash))")
        presenter?.presentInsightsLoading(true)

        Task { @MainActor [weak self] in
            guard let self else { return }
            let insights = await insightsWorker.generateInsights(
                childName: request.childName,
                sounds: request.sounds,
                streakDays: request.streakDays
            )
            presenter?.presentLoadInsights(.init(insights: insights))
        }
    }

    func requestLLMSummary(_ request: ProgressDashboardModels.RequestLLMSummary.Request) {
        guard let service = llmDecisionService else {
            logger.info("LLM service unavailable — fallback")
            presenter?.presentRequestLLMSummary(.init(
                summaryText: Self.fallbackSummary,
                isFallback: true
            ))
            return
        }

        presenter?.presentLLMLoading(true)

        Task { @MainActor [weak self] in
            guard let self else { return }
            // Готовим вход для адаптера. Для Tier B (parent) — вызывает HF API
            // под капотом, fallback к Tier C (rules) при ошибке/таймауте.
            let topSound = request.topSound
            let summaryInput = SessionSummaryInput(
                sessionId: "dashboard-\(Int(Date().timeIntervalSince1970))",
                childId: "child-default",
                childName: request.childName,
                age: 6,
                targetSound: topSound?.sound ?? "—",
                stage: .syllable,
                totalAttempts: 0,
                correctAttempts: 0,
                errorWords: [],
                durationSec: 0,
                date: Date()
            )
            let outcome = await service.generateParentSummary(session: summaryInput)
            logger.info("LLM source=\(outcome.meta.source.rawValue, privacy: .public)")

            let isFallback = outcome.meta.usedFallback || outcome.meta.source == .ruleBased
            let text = outcome.summary.summaryText.isEmpty
                ? Self.fallbackSummary
                : outcome.summary.summaryText

            presenter?.presentRequestLLMSummary(.init(
                summaryText: text,
                isFallback: isFallback
            ))
        }
    }
}

// MARK: - Seed data

private extension ProgressDashboardInteractor {

    static let fallbackSummary = String(localized: "progressDashboard.llm.fallback")

    struct SeedBundle {
        let summary: DashboardSummary
        let daily: [DailyAccuracy]
        let weekly: [WeeklyAccuracy]
        let sounds: [SoundProgress]
        let soundHistory: [String: [DailyAccuracy]]
        let recommendations: [String]
    }

    /// Сгенерировать seed-данные под конкретный период.
    /// Для week — 7 точек по дням; month — 30 точек; quarter — 90 точек.
    /// Weekly chart адаптируется: для quarter — помесячная разбивка (3 точки).
    static func makeSeed(period: ProgressDashboardModels.TimePeriod) -> SeedBundle {
        let daily = makeDaily(for: period)
        let weekly = makeWeekly(for: period)

        let summary = DashboardSummary(
            overallAccuracy: averageAccuracy(in: daily),
            streakDays: streakValue(for: period),
            totalMinutes: minutesValue(for: period),
            totalStars: starsValue(for: period)
        )

        let sounds: [SoundProgress] = [
            SoundProgress(sound: "Р", accuracy: 0.74, sessions: scaledSessions(9, for: period), trend: .up),
            SoundProgress(sound: "Л", accuracy: 0.85, sessions: scaledSessions(7, for: period), trend: .stable),
            SoundProgress(sound: "С", accuracy: 0.68, sessions: scaledSessions(8, for: period), trend: .up),
            SoundProgress(sound: "З", accuracy: 0.90, sessions: scaledSessions(5, for: period), trend: .up),
            SoundProgress(sound: "Ш", accuracy: 0.45, sessions: scaledSessions(6, for: period), trend: .down),
            SoundProgress(sound: "Ж", accuracy: 0.38, sessions: scaledSessions(4, for: period), trend: .down),
            SoundProgress(sound: "Ч", accuracy: 0.55, sessions: scaledSessions(3, for: period), trend: .stable),
            SoundProgress(sound: "Щ", accuracy: 0.78, sessions: scaledSessions(4, for: period), trend: .up)
        ]

        // Для каждого звука — лёгкая вариация дневной кривой.
        var soundHistory: [String: [DailyAccuracy]] = [:]
        for sound in sounds {
            let offset = Double(sound.accuracy - summary.overallAccuracy)
            let history = daily.map { day -> DailyAccuracy in
                let adjusted = max(0.2, min(0.97, Double(day.accuracy) + offset))
                return DailyAccuracy(day: day.day, accuracy: Float(adjusted))
            }
            soundHistory[sound.sound] = history
        }

        let recommendations = makeRecommendations(for: period)

        return SeedBundle(
            summary: summary,
            daily: daily,
            weekly: weekly,
            sounds: sounds,
            soundHistory: soundHistory,
            recommendations: recommendations
        )
    }

    // MARK: - Daily series builder

    static func makeDaily(for period: ProgressDashboardModels.TimePeriod) -> [DailyAccuracy] {
        switch period {
        case .week:
            let labels = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
            let values: [Float] = [0.62, 0.71, 0.65, 0.78, 0.82, 0.74, 0.86]
            return zip(labels, values).map { DailyAccuracy(day: $0, accuracy: $1) }

        case .month:
            // 30 точек, плавный рост от 0.55 → 0.85 с шумом.
            return (0..<30).map { idx in
                let progress = Double(idx) / 29.0
                let base = 0.55 + 0.30 * progress
                let noise = sin(Double(idx) * 1.3) * 0.05
                let value = max(0.30, min(0.95, base + noise))
                return DailyAccuracy(day: "\(idx + 1)", accuracy: Float(value))
            }

        case .quarter:
            // 90 точек, рост 0.50 → 0.88 с волной.
            return (0..<90).map { idx in
                let progress = Double(idx) / 89.0
                let base = 0.50 + 0.38 * progress
                let noise = sin(Double(idx) * 0.6) * 0.04
                let value = max(0.30, min(0.96, base + noise))
                return DailyAccuracy(day: "\(idx + 1)", accuracy: Float(value))
            }
        }
    }

    static func makeWeekly(for period: ProgressDashboardModels.TimePeriod) -> [WeeklyAccuracy] {
        switch period {
        case .week:
            // Прошлые 4 недели для контекста.
            return [
                WeeklyAccuracy(weekIndex: 1, label: "Нед 1", accuracy: 0.61),
                WeeklyAccuracy(weekIndex: 2, label: "Нед 2", accuracy: 0.69),
                WeeklyAccuracy(weekIndex: 3, label: "Нед 3", accuracy: 0.74),
                WeeklyAccuracy(weekIndex: 4, label: "Нед 4", accuracy: 0.81)
            ]
        case .month:
            // 4 недели текущего месяца.
            return [
                WeeklyAccuracy(weekIndex: 1, label: "Нед 1", accuracy: 0.58),
                WeeklyAccuracy(weekIndex: 2, label: "Нед 2", accuracy: 0.67),
                WeeklyAccuracy(weekIndex: 3, label: "Нед 3", accuracy: 0.76),
                WeeklyAccuracy(weekIndex: 4, label: "Нед 4", accuracy: 0.85)
            ]
        case .quarter:
            // 3 месяца квартала.
            return [
                WeeklyAccuracy(weekIndex: 1, label: "Мес 1", accuracy: 0.55),
                WeeklyAccuracy(weekIndex: 2, label: "Мес 2", accuracy: 0.71),
                WeeklyAccuracy(weekIndex: 3, label: "Мес 3", accuracy: 0.84)
            ]
        }
    }

    // MARK: - Aggregation helpers

    static func averageAccuracy(in daily: [DailyAccuracy]) -> Float {
        guard !daily.isEmpty else { return 0 }
        let total = daily.reduce(0) { $0 + $1.accuracy }
        return total / Float(daily.count)
    }

    static func streakValue(for period: ProgressDashboardModels.TimePeriod) -> Int {
        switch period {
        case .week:    return 5
        case .month:   return 18
        case .quarter: return 47
        }
    }

    static func minutesValue(for period: ProgressDashboardModels.TimePeriod) -> Int {
        switch period {
        case .week:    return 127
        case .month:   return 542
        case .quarter: return 1_618
        }
    }

    static func starsValue(for period: ProgressDashboardModels.TimePeriod) -> Int {
        switch period {
        case .week:    return 24
        case .month:   return 96
        case .quarter: return 287
        }
    }

    static func scaledSessions(_ base: Int, for period: ProgressDashboardModels.TimePeriod) -> Int {
        switch period {
        case .week:    return base
        case .month:   return base * 4
        case .quarter: return base * 12
        }
    }

    // MARK: - Recommendations seed

    static func makeRecommendations(for period: ProgressDashboardModels.TimePeriod) -> [String] {
        switch period {
        case .week:
            return [
                String(localized: "progressDashboard.rec.week.1"),
                String(localized: "progressDashboard.rec.week.2"),
                String(localized: "progressDashboard.rec.week.3")
            ]
        case .month:
            return [
                String(localized: "progressDashboard.rec.month.1"),
                String(localized: "progressDashboard.rec.month.2"),
                String(localized: "progressDashboard.rec.month.3"),
                String(localized: "progressDashboard.rec.month.4")
            ]
        case .quarter:
            return [
                String(localized: "progressDashboard.rec.quarter.1"),
                String(localized: "progressDashboard.rec.quarter.2"),
                String(localized: "progressDashboard.rec.quarter.3")
            ]
        }
    }
}

// MARK: - Helpers

private extension DashboardSummary {
    static let empty = DashboardSummary(
        overallAccuracy: 0,
        streakDays: 0,
        totalMinutes: 0,
        totalStars: 0
    )
}
