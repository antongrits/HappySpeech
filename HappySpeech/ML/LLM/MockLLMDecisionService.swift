import Foundation

// MARK: - MockLLMDecisionService
// ==================================================================================
// Deterministic mock of LLMDecisionServiceProtocol for Previews and Tests.
// Every method returns a well-formed, stable value — no randomness.
// Use `useFallbackFlag = true` to simulate LLM absence in tests.
// ==================================================================================

public final class MockLLMDecisionService: LLMDecisionServiceProtocol, @unchecked Sendable {

    public var onDeviceReady: Bool = true
    public var useFallbackFlag: Bool = false
    public var simulatedLatencyMs: Int = 12

    public private(set) var callLog: [String] = []

    private let rules = RuleBasedDecisionService()

    public init(onDeviceReady: Bool = true, useFallbackFlag: Bool = false) {
        self.onDeviceReady = onDeviceReady
        self.useFallbackFlag = useFallbackFlag
    }

    public var isOnDeviceModelReady: Bool {
        get async { onDeviceReady }
    }

    public var downloadProgress: Double { get async { onDeviceReady ? 1.0 : 0.0 } }

    // MARK: - 1

    public func adaptiveRoutePlan(context: RoutePlanContext) async -> RouteDecisionOutcome {
        callLog.append("routePlan")
        let (steps, max) = rules.planDailyRoute(context: context)
        return RouteDecisionOutcome(route: steps, sessionMaxDurationSec: max, meta: meta(.ruleBased, true))
    }

    // MARK: - 2

    public func generateMicroStory(context: StoryContext) async -> StoryDecisionOutcome {
        callLog.append("microStory")
        let story = rules.generateMicroStory(context: context)
        return StoryDecisionOutcome(story: story, meta: meta(source(), usedFallback: useFallbackFlag))
    }

    // MARK: - 3

    public func generateParentSummary(session: SessionSummaryInput) async -> ParentSummaryDecisionOutcome {
        callLog.append("parentSummary")
        if useFallbackFlag || !onDeviceReady {
            let summary = rules.generateParentSummary(session: session)
            return ParentSummaryDecisionOutcome(summary: summary, meta: meta(.ruleBased, true))
        }
        let summary = ParentSummary(
            summaryText: "\(session.childName) отработал «\(session.targetSound)» — \(Int((session.successRate * 100).rounded()))%.",
            homeTask: "Повторите дома слова со звуком «\(session.targetSound)».",
            tone: "supportive"
        )
        return ParentSummaryDecisionOutcome(summary: summary, meta: meta(.onDevice, false))
    }

    // MARK: - 4

    public func pickEncouragementPhrase(context: AttemptContext) async -> EncouragementDecisionOutcome {
        callLog.append("encouragement")
        let (msg, emoji) = rules.pickEncouragementPhrase(context: context)
        return EncouragementDecisionOutcome(message: msg, emoji: emoji, meta: meta(.ruleBased, false))
    }

    // MARK: - 5

    public func pickReward(streak: Int, sessionType: LLMSessionType) async -> RewardDecisionOutcome {
        callLog.append("reward")
        let reward = rules.pickReward(streak: streak, sessionType: sessionType)
        return RewardDecisionOutcome(reward: reward, meta: meta(.ruleBased, false))
    }

    // MARK: - 6

    public func decideFinishSession(fatigueLevel: Double, attempts: Int) async -> FinishDecisionOutcome {
        callLog.append("finishSession")
        let (f, reason) = rules.decideFinishSession(fatigueLevel: fatigueLevel, attempts: attempts)
        return FinishDecisionOutcome(shouldFinish: f, reason: reason, meta: meta(.ruleBased, false))
    }

    // MARK: - 7

    public func adjustDifficulty(recentAttempts: [AttemptOutcome]) async -> DifficultyDecisionOutcome {
        callLog.append("adjustDifficulty")
        let (d, delta, reason) = rules.adjustDifficulty(recentAttempts: recentAttempts)
        return DifficultyDecisionOutcome(difficulty: d, delta: delta, reason: reason, meta: meta(.ruleBased, false))
    }

    // MARK: - 8

    public func analyzeError(attempt: AttemptOutcome, target: String) async -> ErrorAnalysisDecisionOutcome {
        callLog.append("errorAnalysis")
        let analysis = rules.analyzeError(attempt: attempt, target: target)
        return ErrorAnalysisDecisionOutcome(analysis: analysis, meta: meta(.ruleBased, false))
    }

    // MARK: - 9

    public func recommendContent(profile: ChildProfileInput, history: [SessionSummaryInput]) async -> ContentRecommendationOutcome {
        callLog.append("recommendContent")
        let rec = rules.recommendContent(profile: profile, history: history)
        return ContentRecommendationOutcome(recommendation: rec, meta: meta(source(), usedFallback: useFallbackFlag))
    }

    // MARK: - 10

    public func generateSpecialistReport(sessions30d: [SessionSummaryInput]) async -> SpecialistReportOutcome {
        callLog.append("specialistReport")
        let report = rules.generateSpecialistReport(sessions30d: sessions30d)
        return SpecialistReportOutcome(report: report, meta: meta(source(), usedFallback: useFallbackFlag))
    }

    // MARK: - 11

    public func detectFatigue(audioMetrics: AudioMetricsInput, sessionDuration: TimeInterval) async -> FatigueDecisionOutcome {
        callLog.append("detectFatigue")
        let (level, confidence) = rules.detectFatigue(audioMetrics: audioMetrics, sessionDuration: sessionDuration)
        return FatigueDecisionOutcome(level: level, confidence: confidence, meta: meta(.ruleBased, false))
    }

    // MARK: - 12

    public func generateCustomPhrase(template: PhraseTemplate, context: [String: String]) async -> CustomPhraseOutcome {
        callLog.append("customPhrase:\(template.rawValue)")
        let phrase = rules.generateCustomPhrase(template: template, context: context)
        return CustomPhraseOutcome(phrase: phrase, meta: meta(.ruleBased, false))
    }

    // MARK: - 13. Warm-up

    public func selectWarmUp(context: WarmUpContext) async -> WarmUpDecisionOutcome {
        callLog.append("warmUp")
        let result = rules.selectWarmUp(context: context)
        return WarmUpDecisionOutcome(
            activityName: result.activityName,
            instructions: result.instructions,
            durationSeconds: result.durationSeconds,
            meta: meta(.ruleBased, false)
        )
    }

    // MARK: - 14. Word set

    public func generateWordSet(sound: String, stage: CorrectionStage, count: Int) async -> WordSetDecisionOutcome {
        callLog.append("wordSet")
        let result = rules.generateWordSet(sound: sound, stage: stage, count: count)
        return WordSetDecisionOutcome(words: result.words, rationale: result.rationale, meta: meta(source(), usedFallback: useFallbackFlag))
    }

    // MARK: - 15. Minimal pairs

    public func generateMinimalPairs(targetSound: String, confusionSound: String, count: Int) async -> MinimalPairsDecisionOutcome {
        callLog.append("minimalPairs")
        let pairs = rules.generateMinimalPairs(targetSound: targetSound, confusionSound: confusionSound, count: count)
        return MinimalPairsDecisionOutcome(pairs: pairs, meta: meta(.ruleBased, false))
    }

    // MARK: - 16. Narrative quest step

    public func narrativeQuestStep(questState: NarrativeQuestState) async -> NarrativeStepDecisionOutcome {
        callLog.append("narrativeStep")
        let step = rules.narrativeQuestStep(questState: questState)
        return NarrativeStepDecisionOutcome(
            narration: step.narration,
            targetWord: step.targetWord,
            hint: step.hint,
            isLastStep: step.isLastStep,
            meta: meta(source(), usedFallback: useFallbackFlag)
        )
    }

    // MARK: - 17. Child greeting

    public func pickChildGreeting(childName: String, timeOfDay: TimeOfDay, streakDays: Int) async -> GreetingDecisionOutcome {
        callLog.append("greeting")
        let result = rules.pickChildGreeting(childName: childName, timeOfDay: timeOfDay, streakDays: streakDays)
        return GreetingDecisionOutcome(phrase: result.phrase, emoji: result.emoji, meta: meta(.ruleBased, false))
    }

    // MARK: - 18. Celebration

    public func generateCelebration(event: CelebrationEvent) async -> CelebrationDecisionOutcome {
        callLog.append("celebration")
        let result = rules.generateCelebration(event: event)
        return CelebrationDecisionOutcome(message: result.message, animationHint: result.animationHint, meta: meta(.ruleBased, false))
    }

    // MARK: - 19. Rest

    public func recommendRest(sessionDuration: TimeInterval, fatigueLevel: FatigueLevel) async -> RestDecisionOutcome {
        callLog.append("rest")
        let result = rules.recommendRest(sessionDuration: sessionDuration, fatigueLevel: fatigueLevel)
        return RestDecisionOutcome(
            shouldRest: result.shouldRest,
            suggestedBreakMinutes: result.suggestedBreakMinutes,
            message: result.message,
            meta: meta(.ruleBased, false)
        )
    }

    // MARK: - 20. Transition

    public func playfulTransition(fromActivity: TemplateType, toActivity: TemplateType) async -> TransitionDecisionOutcome {
        callLog.append("transition")
        let phrase = rules.playfulTransition(fromActivity: fromActivity, toActivity: toActivity)
        return TransitionDecisionOutcome(phrase: phrase, meta: meta(.ruleBased, false))
    }

    // MARK: - 21. Surprise fact

    public func generateSurpriseFact(topic: String, childAge: Int) async -> SurpriseFactDecisionOutcome {
        callLog.append("surpriseFact")
        let fact = rules.generateSurpriseFact(topic: topic, childAge: childAge)
        return SurpriseFactDecisionOutcome(fact: fact, meta: meta(source(), usedFallback: useFallbackFlag))
    }

    // MARK: - 22. Weekly report

    public func generateWeeklyReport(weeks: [WeekSummaryInput]) async -> WeeklyReportDecisionOutcome {
        callLog.append("weeklyReport")
        let result = rules.generateWeeklyReport(weeks: weeks)
        return WeeklyReportDecisionOutcome(
            summary: result.summary,
            highlights: result.highlights,
            recommendations: result.recommendations,
            meta: meta(source(), usedFallback: useFallbackFlag)
        )
    }

    // MARK: - 23. Parent tip

    public func generateParentTip(profile: ChildProfileInput, currentStage: CorrectionStage) async -> ParentTipDecisionOutcome {
        callLog.append("parentTip")
        let result = rules.generateParentTip(profile: profile, currentStage: currentStage)
        return ParentTipDecisionOutcome(
            tip: result.tip,
            exerciseSuggestion: result.exerciseSuggestion,
            meta: meta(source(), usedFallback: useFallbackFlag)
        )
    }

    // MARK: - 24. Anxiety detection

    public func detectAnxiety(sessionMetrics: SessionMetricsInput) async -> AnxietyDecisionOutcome {
        callLog.append("anxiety")
        let result = rules.detectAnxiety(sessionMetrics: sessionMetrics)
        return AnxietyDecisionOutcome(
            anxietyScore: result.score,
            signals: result.signals,
            recommendation: result.recommendation,
            meta: meta(.ruleBased, false)
        )
    }

    // MARK: - 25. Goal adjustment

    public func suggestGoalAdjustment(progress: ProgressTrendInput) async -> GoalAdjustmentDecisionOutcome {
        callLog.append("goalAdjustment")
        let result = rules.suggestGoalAdjustment(progress: progress)
        return GoalAdjustmentDecisionOutcome(
            currentGoal: result.currentGoal,
            suggestedGoal: result.suggestedGoal,
            rationale: result.rationale,
            meta: meta(source(), usedFallback: useFallbackFlag)
        )
    }

    // MARK: - helpers

    private func source() -> LLMDecisionSource {
        if useFallbackFlag || !onDeviceReady { return .ruleBased }
        return .onDevice
    }

    private func meta(_ src: LLMDecisionSource, _ usedFallback: Bool) -> LLMDecisionMeta {
        LLMDecisionMeta(
            source: src,
            latencyMs: simulatedLatencyMs,
            usedFallback: usedFallback,
            modelId: src == .onDevice ? LLMInferenceActor.modelId : nil
        )
    }

    private func meta(_ src: LLMDecisionSource, usedFallback: Bool) -> LLMDecisionMeta {
        meta(src, usedFallback)
    }
}
