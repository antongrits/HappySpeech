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
/// Источник данных — РЕАЛЬНЫЕ агрегаты из `ProgressDashboardWorker`
/// (`SessionRepository` + `ChildRepository`): точность по дням/неделям,
/// серия дней, минуты, звёзды и прогресс по звукам считаются из накопленных
/// сессий ребёнка. Если сессий нет (новый ребёнок) — возвращается пустое
/// состояние, и Presenter показывает честное «пока нет занятий».
///
/// LLM-сводку запрашиваем у `LLMDecisionService`; если сервис возвращает
/// ошибку или работает медленно — Presenter показывает статичный текст-фолбэк.
@MainActor
final class ProgressDashboardInteractor: ProgressDashboardBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any ProgressDashboardPresentationLogic)?

    private let llmDecisionService: (any LLMDecisionServiceProtocol)?
    private let worker: (any ProgressDashboardAggregating)?
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

    init(
        worker: (any ProgressDashboardAggregating)? = nil,
        llmDecisionService: (any LLMDecisionServiceProtocol)? = nil
    ) {
        self.worker = worker
        self.llmDecisionService = llmDecisionService
    }

    // MARK: - BusinessLogic

    func loadDashboard(_ request: ProgressDashboardModels.LoadDashboard.Request) {
        logger.info(
            "loadDashboard child=\(request.childId, privacy: .private(mask: .hash)) period=\(request.period.rawValue, privacy: .public)"
        )
        lastChildId = request.childId
        currentPeriod = request.period
        presenter?.presentLoading(true)

        Task { @MainActor [weak self] in
            guard let self else { return }
            let aggregate = await worker?.aggregate(childId: request.childId, period: request.period)
                ?? .empty
            self.apply(aggregate, period: request.period)
        }
    }

    /// Применить реальные агрегаты к state и презентовать.
    private func apply(_ aggregate: DashboardAggregate, period: ProgressDashboardModels.TimePeriod) {
        summary = aggregate.summary
        dailyAccuracy = aggregate.daily
        weeklyAccuracy = aggregate.weekly
        sounds = aggregate.sounds
        soundHistory = aggregate.soundHistory
        recommendations = Self.makeRecommendations(from: aggregate.sounds)

        let response = ProgressDashboardModels.LoadDashboard.Response(
            summary: summary,
            dailyAccuracy: dailyAccuracy,
            weeklyAccuracy: weeklyAccuracy,
            sounds: sounds,
            recommendations: recommendations,
            period: period
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
            // Готовим вход для адаптера на РЕАЛЬНЫХ агрегатах периода. Для Tier B
            // (parent) — вызывает HF API под капотом, fallback к Tier C при ошибке.
            let topSound = request.topSound
            let realSummary = self.summary
            // Восстанавливаем попытки из общей точности и числа сессий по топ-звуку,
            // чтобы LLM описывал настоящий прогресс, а не нули.
            let attemptsBasis = max(topSound?.sessions ?? 0, 1) * 10
            let correctBasis = Int((Double(attemptsBasis) * Double(realSummary.overallAccuracy)).rounded())
            let summaryInput = SessionSummaryInput(
                sessionId: "dashboard-\(Int(Date().timeIntervalSince1970))",
                childId: self.lastChildId,
                childName: request.childName,
                age: 6,
                targetSound: topSound?.sound ?? "—",
                stage: .syllable,
                totalAttempts: attemptsBasis,
                correctAttempts: correctBasis,
                errorWords: [],
                durationSec: realSummary.totalMinutes * 60,
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

// MARK: - Recommendations (выводятся из РЕАЛЬНЫХ данных)

private extension ProgressDashboardInteractor {

    static let fallbackSummary = String(localized: "progressDashboard.llm.fallback")

    /// Рекомендации строятся из реального прогресса по звукам:
    /// - звуки с точностью < 60% → «уделить внимание»;
    /// - звуки с точностью ≥ 85% → «закрепить успех»;
    /// - если данных пока нет — общая рекомендация начать заниматься.
    static func makeRecommendations(from sounds: [SoundProgress]) -> [String] {
        guard !sounds.isEmpty else {
            return [String(localized: "progressDashboard.rec.empty")]
        }

        var result: [String] = []

        let needsWork = sounds
            .filter { $0.accuracy < 0.60 }
            .sorted { $0.accuracy < $1.accuracy }
            .prefix(2)
        for sound in needsWork {
            result.append(String(
                format: String(localized: "progressDashboard.rec.focusPattern"),
                sound.sound
            ))
        }

        if let best = sounds.filter({ $0.accuracy >= 0.85 }).max(by: { $0.accuracy < $1.accuracy }) {
            result.append(String(
                format: String(localized: "progressDashboard.rec.reinforcePattern"),
                best.sound
            ))
        }

        if result.isEmpty {
            // Все звуки в среднем диапазоне — поощряем регулярность.
            result.append(String(localized: "progressDashboard.rec.keepGoing"))
        }

        return result
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
