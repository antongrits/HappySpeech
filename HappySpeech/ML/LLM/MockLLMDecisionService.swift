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
