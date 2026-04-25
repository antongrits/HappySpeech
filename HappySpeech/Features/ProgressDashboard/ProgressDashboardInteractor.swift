import Foundation
import OSLog

// MARK: - ProgressDashboardBusinessLogic

@MainActor
protocol ProgressDashboardBusinessLogic: AnyObject {
    func loadDashboard(_ request: ProgressDashboardModels.LoadDashboard.Request)
    func loadSoundDetail(_ request: ProgressDashboardModels.LoadSoundDetail.Request)
    func requestLLMSummary(_ request: ProgressDashboardModels.RequestLLMSummary.Request)
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

    // MARK: - State

    private var summary: DashboardSummary = .empty
    private var dailyAccuracy: [DailyAccuracy] = []
    private var weeklyAccuracy: [WeeklyAccuracy] = []
    private var sounds: [SoundProgress] = []
    private var soundHistory: [String: [DailyAccuracy]] = [:]

    // MARK: - Init

    init(llmDecisionService: (any LLMDecisionServiceProtocol)? = nil) {
        self.llmDecisionService = llmDecisionService
    }

    // MARK: - BusinessLogic

    func loadDashboard(_ request: ProgressDashboardModels.LoadDashboard.Request) {
        logger.info("loadDashboard child=\(request.childId, privacy: .private(mask: .hash))")

        let seed = Self.makeSeed()
        summary = seed.summary
        dailyAccuracy = seed.daily
        weeklyAccuracy = seed.weekly
        sounds = seed.sounds
        soundHistory = seed.soundHistory

        let response = ProgressDashboardModels.LoadDashboard.Response(
            summary: summary,
            dailyAccuracy: dailyAccuracy,
            weeklyAccuracy: weeklyAccuracy,
            sounds: sounds
        )
        presenter?.presentLoadDashboard(response)
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

    func requestLLMSummary(_ request: ProgressDashboardModels.RequestLLMSummary.Request) {
        guard let service = llmDecisionService else {
            logger.info("LLM service unavailable — fallback")
            presenter?.presentRequestLLMSummary(.init(
                summaryText: Self.fallbackSummary,
                isFallback: true
            ))
            return
        }

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
    }

    static func makeSeed() -> SeedBundle {
        let dailyLabels = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
        let dailyValues: [Float] = [0.62, 0.71, 0.65, 0.78, 0.82, 0.74, 0.86]
        let daily = zip(dailyLabels, dailyValues).map { label, value in
            DailyAccuracy(day: label, accuracy: value)
        }

        let weekly: [WeeklyAccuracy] = [
            WeeklyAccuracy(weekIndex: 1, label: "Нед 1", accuracy: 0.61),
            WeeklyAccuracy(weekIndex: 2, label: "Нед 2", accuracy: 0.69),
            WeeklyAccuracy(weekIndex: 3, label: "Нед 3", accuracy: 0.74),
            WeeklyAccuracy(weekIndex: 4, label: "Нед 4", accuracy: 0.81)
        ]

        let summary = DashboardSummary(
            overallAccuracy: 0.78,
            streakDays: 5,
            totalMinutes: 127,
            totalStars: 24
        )

        let sounds: [SoundProgress] = [
            SoundProgress(sound: "Р", accuracy: 0.74, sessions: 9, trend: .up),
            SoundProgress(sound: "Л", accuracy: 0.82, sessions: 7, trend: .stable),
            SoundProgress(sound: "С", accuracy: 0.69, sessions: 8, trend: .up),
            SoundProgress(sound: "З", accuracy: 0.71, sessions: 5, trend: .stable),
            SoundProgress(sound: "Ш", accuracy: 0.91, sessions: 6, trend: .up),
            SoundProgress(sound: "Ж", accuracy: 0.66, sessions: 4, trend: .down),
            SoundProgress(sound: "К", accuracy: 0.85, sessions: 3, trend: .stable),
            SoundProgress(sound: "Ц", accuracy: 0.55, sessions: 4, trend: .down)
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

        return SeedBundle(
            summary: summary,
            daily: daily,
            weekly: weekly,
            sounds: sounds,
            soundHistory: soundHistory
        )
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
