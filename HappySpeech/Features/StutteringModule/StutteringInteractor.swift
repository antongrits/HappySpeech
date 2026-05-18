import Foundation
import OSLog

// MARK: - StutteringBusinessLogic

@MainActor
protocol StutteringBusinessLogic: AnyObject {
    func loadScreen(_ request: StutteringModels.LoadScreen.Request)
    func selectMode(_ request: StutteringModels.SelectMode.Request)
    func loadProgress(_ request: StutteringModels.LoadProgress.Request)
    func loadAdaptiveRecommendation(_ request: StutteringModels.LoadAdaptiveRecommendation.Request)
    func recordSessionCompleted(_ request: StutteringModels.RecordSessionCompleted.Request)
}

// MARK: - StutteringInteractor

@MainActor
final class StutteringInteractor: StutteringBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any StutteringPresentationLogic)?

    private let logger = HSLogger.ui
    private let defaults = UserDefaults.standard

    // MARK: - UserDefaults Keys

    private let welcomeSeenKey = "stuttering_welcome_shown"
    private let sessionCountKey = "stuttering_session_count_total"
    private let lastSessionDateKey = "stuttering_last_session_date"
    private let streakKeyPrefix = "stuttering_streak_"
    private let completedTodayKeyPrefix = "stuttering_completed_today_"
    private let fluencyImprovementKey = "stuttering_fluency_improvement_pct"
    private let recommendedModeKey = "stuttering_recommended_mode"
    private let voicePromptPlayedKey = "stuttering_voice_prompt_played_"

    // MARK: - LoadScreen

    func loadScreen(_ request: StutteringModels.LoadScreen.Request) {
        let cards = buildAllCards()
        let hasSeenWelcome = defaults.bool(forKey: welcomeSeenKey)
        let response = StutteringModels.LoadScreen.Response(
            cards: cards,
            hasSeenWelcome: hasSeenWelcome
        )
        presenter?.presentLoadScreen(response)
        logger.info("StutteringInteractor: loadScreen hasSeenWelcome=\(hasSeenWelcome, privacy: .public) cards=\(cards.count, privacy: .public)")
    }

    // MARK: - SelectMode

    func selectMode(_ request: StutteringModels.SelectMode.Request) {
        logger.info("StutteringInteractor: selectMode=\(request.mode.rawValue, privacy: .public)")
        presenter?.presentSelectMode(.init(mode: request.mode))
    }

    // MARK: - LoadProgress

    func loadProgress(_ request: StutteringModels.LoadProgress.Request) {
        var featureProgress: [StutteringMode: FeatureProgress] = [:]
        for mode in StutteringMode.allCases {
            let streak = defaults.integer(forKey: streakKeyPrefix + mode.rawValue)
            let completedToday = isCompletedToday(mode: mode)
            featureProgress[mode] = FeatureProgress(
                mode: mode,
                streak: streak,
                completedToday: completedToday
            )
        }
        let totalSessions = defaults.integer(forKey: sessionCountKey)
        let improvementPct = defaults.float(forKey: fluencyImprovementKey)
        let response = StutteringModels.LoadProgress.Response(
            featureProgress: featureProgress,
            totalSessions: totalSessions,
            fluencyImprovementPct: improvementPct
        )
        presenter?.presentLoadProgress(response)
        logger.info("StutteringInteractor: loadProgress totalSessions=\(totalSessions, privacy: .public) improvement=\(improvementPct, privacy: .public)")
    }

    // MARK: - LoadAdaptiveRecommendation

    func loadAdaptiveRecommendation(_ request: StutteringModels.LoadAdaptiveRecommendation.Request) {
        let recommended = computeAdaptiveRecommendation()
        let voicePrompt = buildVoicePrompt(for: recommended)
        let response = StutteringModels.LoadAdaptiveRecommendation.Response(
            recommendedMode: recommended,
            voicePromptText: voicePrompt,
            shouldShowGlow: true
        )
        defaults.set(recommended.rawValue, forKey: recommendedModeKey)
        presenter?.presentAdaptiveRecommendation(response)
        logger.info("StutteringInteractor: adaptiveRecommendation=\(recommended.rawValue, privacy: .public)")
    }

    // MARK: - RecordSessionCompleted

    func recordSessionCompleted(_ request: StutteringModels.RecordSessionCompleted.Request) {
        let mode = request.mode
        incrementStreak(for: mode)
        markCompletedToday(mode: mode)
        let newTotal = defaults.integer(forKey: sessionCountKey) + 1
        defaults.set(newTotal, forKey: sessionCountKey)
        defaults.set(Date(), forKey: lastSessionDateKey)
        if request.fluencyScore > 0 {
            updateFluencyImprovement(newScore: request.fluencyScore)
        }
        logger.info("StutteringInteractor: sessionCompleted mode=\(mode.rawValue, privacy: .public) score=\(request.fluencyScore, privacy: .public)")
    }

    // MARK: - Welcome dismiss

    func markWelcomeSeen() {
        defaults.set(true, forKey: welcomeSeenKey)
        logger.info("StutteringInteractor: welcome marked seen")
    }

    // MARK: - Private: Card Building

    private func buildAllCards() -> [ExerciseCardData] {
        [
            ExerciseCardData(
                mode: .metronome,
                titleKey: "stuttering.exercise.metronome.title",
                subtitleKey: "stuttering.exercise.metronome.subtitle",
                symbol: "metronome",
                symbolColor: .primary,
                duration: "~5 мин"
            ),
            ExerciseCardData(
                mode: .breathing,
                titleKey: "stuttering.exercise.breathing.title",
                subtitleKey: "stuttering.exercise.breathing.subtitle",
                symbol: "leaf.fill",
                symbolColor: .mint,
                duration: "~3 мин"
            ),
            ExerciseCardData(
                mode: .softOnset,
                titleKey: "stuttering.exercise.soft_start.title",
                subtitleKey: "stuttering.exercise.soft_start.subtitle",
                symbol: "light.beacon.max",
                symbolColor: .butter,
                duration: "~5 мин"
            ),
            ExerciseCardData(
                mode: .diary,
                titleKey: "stuttering.exercise.diary.title",
                subtitleKey: "stuttering.exercise.diary.subtitle",
                symbol: "book.fill",
                symbolColor: .sky,
                duration: "~1 мин"
            ),
            ExerciseCardData(
                mode: .pacing,
                titleKey: "stuttering.exercise.pacing.title",
                subtitleKey: "stuttering.exercise.pacing.subtitle",
                symbol: "timer",
                symbolColor: .rose,
                duration: "~4 мин"
            )
        ]
    }

    // MARK: - Private: Adaptive Recommendation

    private func computeAdaptiveRecommendation() -> StutteringMode {
        // Prefer mode that has not been completed today
        let pendingModes = StutteringMode.allCases.filter { !isCompletedToday(mode: $0) }
        if let first = pendingModes.first {
            return first
        }
        // All done today — recommend the one with lowest streak to reinforce
        let lowestStreak = StutteringMode.allCases.min(by: { modeA, modeB in
            defaults.integer(forKey: streakKeyPrefix + modeA.rawValue)
                < defaults.integer(forKey: streakKeyPrefix + modeB.rawValue)
        })
        return lowestStreak ?? .softOnset
    }

    private func buildVoicePrompt(for mode: StutteringMode) -> String {
        switch mode {
        case .metronome:
            return String(localized: "stuttering.voice.recommend.metronome")
        case .breathing:
            return String(localized: "stuttering.voice.recommend.breathing")
        case .softOnset:
            return String(localized: "stuttering.voice.recommend.soft_onset")
        case .diary:
            return String(localized: "stuttering.voice.recommend.diary")
        case .pacing:
            return String(localized: "stuttering.voice.recommend.pacing")
        }
    }

    // MARK: - Private: Progress Helpers

    private func isCompletedToday(mode: StutteringMode) -> Bool {
        let key = completedTodayKeyPrefix + mode.rawValue
        guard let savedDate = defaults.object(forKey: key) as? Date else { return false }
        return Calendar.current.isDateInToday(savedDate)
    }

    private func markCompletedToday(mode: StutteringMode) {
        let key = completedTodayKeyPrefix + mode.rawValue
        defaults.set(Date(), forKey: key)
    }

    private func incrementStreak(for mode: StutteringMode) {
        let key = streakKeyPrefix + mode.rawValue
        let lastKey = "stuttering_streak_last_date_" + mode.rawValue
        let currentStreak = defaults.integer(forKey: key)
        if let lastDate = defaults.object(forKey: lastKey) as? Date {
            let diff = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
            if diff == 1 {
                defaults.set(currentStreak + 1, forKey: key)
            } else if diff > 1 {
                defaults.set(1, forKey: key)
            }
        } else {
            defaults.set(1, forKey: key)
        }
        defaults.set(Date(), forKey: lastKey)
    }

    private func updateFluencyImprovement(newScore: Float) {
        let current = defaults.float(forKey: fluencyImprovementKey)
        let sessionCount = max(1, defaults.integer(forKey: sessionCountKey))
        // Running average with decay towards new score
        let alpha: Float = 1.0 / Float(sessionCount)
        let updated = current * (1.0 - alpha) + newScore * alpha
        defaults.set(updated, forKey: fluencyImprovementKey)
    }

    // MARK: - Session Duration Guidance

    /// Рекомендованная длительность сессии по возрасту (минуты).
    /// 5–6 лет: 7–10 мин, 6–7 лет: 10–12 мин, 7–8 лет: 12–15 мин.
    func recommendedSessionDuration(ageYears: Int) -> ClosedRange<Int> {
        switch ageYears {
        case ...5:  return 7...10
        case 6:     return 10...12
        case 7...:  return 12...15
        default:    return 7...10
        }
    }

    // MARK: - Weekly Completion Summary

    /// Количество режимов выполненных за сегодня.
    func completedModesTodayCount() -> Int {
        StutteringMode.allCases.filter { isCompletedToday(mode: $0) }.count
    }

    /// Общий стрик по всем режимам (минимальный стрик среди всех).
    func overallStreakDays() -> Int {
        StutteringMode.allCases.map {
            defaults.integer(forKey: streakKeyPrefix + $0.rawValue)
        }.min() ?? 0
    }

    // MARK: - Reset Streak

    /// Сброс стрика для режима (если пользователь пропустил день).
    func resetStreakIfNeeded(for mode: StutteringMode) {
        let lastKey = "stuttering_streak_last_date_" + mode.rawValue
        guard let lastDate = defaults.object(forKey: lastKey) as? Date else { return }
        let diff = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        if diff > 1 {
            defaults.set(0, forKey: streakKeyPrefix + mode.rawValue)
            logger.info("StutteringInteractor: streak reset for mode=\(mode.rawValue, privacy: .public)")
        }
    }

    /// Проверяет и сбрасывает стрики для всех режимов при старте.
    func validateAllStreaks() {
        for mode in StutteringMode.allCases {
            resetStreakIfNeeded(for: mode)
        }
    }

    // MARK: - Mode Icon Helper

    /// SF Symbol для заданного режима (используется в уведомлениях, виджетах).
    func symbol(for mode: StutteringMode) -> String {
        switch mode {
        case .metronome:       return "metronome"
        case .breathing:       return "leaf.fill"
        case .softOnset:       return "light.beacon.max"
        case .diary:           return "book.fill"
        case .pacing:          return "timer"
        }
    }
}
