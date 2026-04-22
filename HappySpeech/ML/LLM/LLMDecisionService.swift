import Foundation
import OSLog

// MARK: - LiveLLMDecisionService
// ==================================================================================
// Implements all 12 decision points with tiered routing:
//   Tier A — On-device LLM (Qwen2.5-1.5B) via LLMInferenceActor
//            Used for: kid circuit, parent circuit (when model downloaded).
//   Tier B — HF Inference API (Vikhr-Nemo-12B) via HFInferenceClient
//            Used for: parent + specialist circuits ONLY — never for kid (COPPA).
//   Tier C — RuleBasedDecisionService — always works, final fallback.
//
// Latency budgets (master-plan §19.5) are enforced with `withTimeout`:
//   if the LLM misses the budget, we silently switch to rule-based.
//
// Every call writes a decision log entry (see LLMDecisionLog Realm model) for
// later offline analytics / QA dashboards.
// ==================================================================================

public final class LiveLLMDecisionService: LLMDecisionServiceProtocol, @unchecked Sendable {

    // MARK: - Dependencies
    private let inferenceActor: LLMInferenceActor
    private let hfClient: any HFInferenceClientProtocol
    private let rules: RuleBasedDecisionService
    private let networkMonitor: any NetworkMonitorService
    private let logRepository: any LLMDecisionLogRepository

    public init(
        inferenceActor: LLMInferenceActor,
        hfClient: any HFInferenceClientProtocol,
        rules: RuleBasedDecisionService = RuleBasedDecisionService(),
        networkMonitor: any NetworkMonitorService,
        logRepository: any LLMDecisionLogRepository
    ) {
        self.inferenceActor = inferenceActor
        self.hfClient = hfClient
        self.rules = rules
        self.networkMonitor = networkMonitor
        self.logRepository = logRepository
    }

    // MARK: - Model State

    public var isOnDeviceModelReady: Bool {
        get async { await inferenceActor.isReady }
    }

    public var downloadProgress: Double { get async { 0 } }

    // MARK: - 1. Route

    public func adaptiveRoutePlan(context: RoutePlanContext) async -> RouteDecisionOutcome {
        let start = Date()

        if await inferenceActor.isReady {
            let request = RoutePlannerRequest(
                childId: context.childId,
                targetSound: context.targetSound,
                currentStage: context.currentStage.rawValue,
                recentSuccessRate: context.recentSuccessRate,
                fatigueLevel: context.fatigueLevel.rawValue,
                age: context.age,
                availableTemplates: context.availableTemplates.map(\.rawValue)
            )
            if let resp = await withTimeout(ms: 2_000, { [inferenceActor] in
                try? await inferenceActor.generateRoute(request)
            }) {
                let steps = resp.route.compactMap { item -> RouteStepItem? in
                    guard let template = TemplateType(rawValue: item.template) else { return nil }
                    return RouteStepItem(
                        templateType: template,
                        targetSound: context.targetSound,
                        stage: context.currentStage,
                        difficulty: item.difficulty,
                        wordCount: item.wordCount,
                        durationTargetSec: item.durationTargetSec
                    )
                }
                if !steps.isEmpty {
                    let meta = makeMeta(start: start, source: .onDevice, usedFallback: false)
                    logDecision(kind: "routePlan", meta: meta, output: "\(steps.count) steps, max \(resp.sessionMaxDurationSec)s", childId: context.childId)
                    return RouteDecisionOutcome(route: steps, sessionMaxDurationSec: resp.sessionMaxDurationSec, meta: meta)
                }
            }
        }

        // Fallback
        let (steps, maxDuration) = rules.planDailyRoute(context: context)
        let meta = makeMeta(start: start, source: .ruleBased, usedFallback: true)
        logDecision(kind: "routePlan", meta: meta, output: "rules:\(steps.count)steps", childId: context.childId)
        return RouteDecisionOutcome(route: steps, sessionMaxDurationSec: maxDuration, meta: meta)
    }

    // MARK: - 2. Micro-story

    public func generateMicroStory(context: StoryContext) async -> StoryDecisionOutcome {
        let start = Date()

        if await inferenceActor.isReady {
            let request = MicroStoryRequest(
                targetSound: context.targetSound,
                stage: context.stage.rawValue,
                age: context.age,
                wordPool: context.wordPool
            )
            if let resp = await withTimeout(ms: 2_500, { [inferenceActor] in
                try? await inferenceActor.generateMicroStory(request)
            }) {
                let story = MicroStory(
                    sentences: resp.sentences,
                    gaps: resp.gapPositions.map { .init(sentenceIndex: $0.sentenceIndex, word: $0.word, imageHint: $0.imageHint) }
                )
                let meta = makeMeta(start: start, source: .onDevice, usedFallback: false)
                logDecision(kind: "microStory", meta: meta, output: "\(story.sentences.count)sent", childId: nil)
                return StoryDecisionOutcome(story: story, meta: meta)
            }
        }

        let story = rules.generateMicroStory(context: context)
        let meta = makeMeta(start: start, source: .ruleBased, usedFallback: true)
        logDecision(kind: "microStory", meta: meta, output: "rules:\(story.sentences.count)", childId: nil)
        return StoryDecisionOutcome(story: story, meta: meta)
    }

    // MARK: - 3. Parent summary

    public func generateParentSummary(session: SessionSummaryInput) async -> ParentSummaryDecisionOutcome {
        let start = Date()

        // On-device preferred
        if await inferenceActor.isReady {
            let request = ParentSummaryRequest(
                childName: session.childName,
                targetSound: session.targetSound,
                stage: session.stage.rawValue,
                totalAttempts: session.totalAttempts,
                correctAttempts: session.correctAttempts,
                errorWords: session.errorWords,
                sessionDurationSec: session.durationSec
            )
            if let resp = await withTimeout(ms: 3_000, { [inferenceActor] in
                try? await inferenceActor.generateParentSummary(request)
            }) {
                let summary = ParentSummary(
                    summaryText: resp.parentSummary,
                    homeTask: resp.homeTask,
                    tone: "supportive"
                )
                let meta = makeMeta(start: start, source: .onDevice, usedFallback: false)
                logDecision(kind: "parentSummary", meta: meta, output: summary.summaryText.prefix(50).description, childId: session.childId)
                return ParentSummaryDecisionOutcome(summary: summary, meta: meta)
            }
        }

        // Try HF Inference API if we're online (parent circuit)
        if networkMonitor.isConnected, hfClient.isConfigured {
            let prompt = LLMPrompts.render(LLMPrompts.userParentSummaryTemplate, values: [
                "child_name": session.childName,
                "age": "\(session.age)",
                "target_sound": session.targetSound,
                "stage": session.stage.rawValue,
                "total": "\(session.totalAttempts)",
                "correct": "\(session.correctAttempts)",
                "rate": "\(Int((session.successRate * 100).rounded()))",
                "error_words": session.errorWords.joined(separator: ", "),
                "duration_sec": "\(session.durationSec)"
            ])
            let full = LLMPrompts.systemParentSummary + "\n" + prompt
            if let text = await withTimeout(ms: 3_000, { [hfClient] in
                try? await hfClient.generate(model: HFInferenceClient.modelVikhrNemo, prompt: full, maxTokens: LLMPrompts.MaxTokens.parentSummary, timeoutMs: 3_000)
            }), let summary = JSONParser.parseParentSummary(text) {
                let meta = makeMeta(start: start, source: .hfInference, usedFallback: false)
                logDecision(kind: "parentSummary", meta: meta, output: "hf:\(summary.summaryText.prefix(40))", childId: session.childId)
                return ParentSummaryDecisionOutcome(summary: summary, meta: meta)
            }
        }

        // Rule-based fallback
        let summary = rules.generateParentSummary(session: session)
        let meta = makeMeta(start: start, source: .ruleBased, usedFallback: true)
        logDecision(kind: "parentSummary", meta: meta, output: "rules", childId: session.childId)
        return ParentSummaryDecisionOutcome(summary: summary, meta: meta)
    }

    // MARK: - 4. Encouragement (kid circuit — on-device or rules only)

    public func pickEncouragementPhrase(context: AttemptContext) async -> EncouragementDecisionOutcome {
        let start = Date()
        // Kid circuit: NEVER hit the network. Rules provide a tight latency budget.
        let (message, emoji) = rules.pickEncouragementPhrase(context: context)
        let meta = makeMeta(start: start, source: .ruleBased, usedFallback: false)
        logDecision(kind: "encouragement", meta: meta, output: message, childId: nil)
        return EncouragementDecisionOutcome(message: message, emoji: emoji, meta: meta)
    }

    // MARK: - 5. Reward

    public func pickReward(streak: Int, sessionType: SessionType) async -> RewardDecisionOutcome {
        let start = Date()
        let reward = rules.pickReward(streak: streak, sessionType: sessionType)
        let meta = makeMeta(start: start, source: .ruleBased, usedFallback: false)
        logDecision(kind: "reward", meta: meta, output: reward.stickerId, childId: nil)
        return RewardDecisionOutcome(reward: reward, meta: meta)
    }

    // MARK: - 6. Finish session

    public func decideFinishSession(fatigueLevel: Double, attempts: Int) async -> FinishDecisionOutcome {
        let start = Date()
        let (finish, reason) = rules.decideFinishSession(fatigueLevel: fatigueLevel, attempts: attempts)
        let meta = makeMeta(start: start, source: .ruleBased, usedFallback: false)
        logDecision(kind: "finishSession", meta: meta, output: finish ? "finish" : "continue", childId: nil)
        return FinishDecisionOutcome(shouldFinish: finish, reason: reason, meta: meta)
    }

    // MARK: - 7. Adjust difficulty

    public func adjustDifficulty(recentAttempts: [AttemptOutcome]) async -> DifficultyDecisionOutcome {
        let start = Date()
        let (difficulty, delta, reason) = rules.adjustDifficulty(recentAttempts: recentAttempts)
        let meta = makeMeta(start: start, source: .ruleBased, usedFallback: false)
        logDecision(kind: "adjustDifficulty", meta: meta, output: "\(difficulty.rawValue)/\(delta)", childId: nil)
        return DifficultyDecisionOutcome(difficulty: difficulty, delta: delta, reason: reason, meta: meta)
    }

    // MARK: - 8. Error analysis

    public func analyzeError(attempt: AttemptOutcome, target: String) async -> ErrorAnalysisDecisionOutcome {
        let start = Date()
        let analysis = rules.analyzeError(attempt: attempt, target: target)
        let meta = makeMeta(start: start, source: .ruleBased, usedFallback: false)
        logDecision(kind: "errorAnalysis", meta: meta, output: analysis.category.rawValue, childId: nil)
        return ErrorAnalysisDecisionOutcome(analysis: analysis, meta: meta)
    }

    // MARK: - 9. Recommend content

    public func recommendContent(profile: ChildProfileInput, history: [SessionSummaryInput]) async -> ContentRecommendationOutcome {
        let start = Date()

        // Parent/specialist circuit — may use HF.
        if networkMonitor.isConnected, hfClient.isConfigured {
            let prompt = LLMPrompts.render(LLMPrompts.userContentRecommendTemplate, values: [
                "child_name": profile.name,
                "age": "\(profile.age)",
                "target_sounds": profile.targetSounds.joined(separator: ", "),
                "progress_map": progressJSON(profile.progressSummary),
                "recent_sessions": sessionsJSON(history.prefix(5).map { $0 })
            ])
            let full = LLMPrompts.systemContentRecommend + "\n" + prompt
            if let text = await withTimeout(ms: 3_000, { [hfClient] in
                try? await hfClient.generate(model: HFInferenceClient.modelVikhrNemo, prompt: full, maxTokens: LLMPrompts.MaxTokens.contentRecommend, timeoutMs: 3_000)
            }), let rec = JSONParser.parseContentRecommendation(text) {
                let meta = makeMeta(start: start, source: .hfInference, usedFallback: false)
                logDecision(kind: "recommendContent", meta: meta, output: "hf:\(rec.packIds.count)", childId: profile.id)
                return ContentRecommendationOutcome(recommendation: rec, meta: meta)
            }
        }

        let rec = rules.recommendContent(profile: profile, history: history)
        let meta = makeMeta(start: start, source: .ruleBased, usedFallback: true)
        logDecision(kind: "recommendContent", meta: meta, output: "rules:\(rec.packIds.count)", childId: profile.id)
        return ContentRecommendationOutcome(recommendation: rec, meta: meta)
    }

    // MARK: - 10. Specialist report

    public func generateSpecialistReport(sessions30d: [SessionSummaryInput]) async -> SpecialistReportOutcome {
        let start = Date()

        if networkMonitor.isConnected, hfClient.isConfigured {
            let prompt = LLMPrompts.render(LLMPrompts.userSpecialistReportTemplate, values: [
                "sessions_json": sessionsJSON(sessions30d)
            ])
            let full = LLMPrompts.systemSpecialistReport + "\n" + prompt
            if let text = await withTimeout(ms: 5_000, { [hfClient] in
                try? await hfClient.generate(model: HFInferenceClient.modelVikhrNemo, prompt: full, maxTokens: LLMPrompts.MaxTokens.specialistReport, timeoutMs: 5_000)
            }), let report = JSONParser.parseSpecialistReport(text) {
                let meta = makeMeta(start: start, source: .hfInference, usedFallback: false)
                logDecision(kind: "specialistReport", meta: meta, output: "hf:\(report.headline.prefix(40))", childId: sessions30d.first?.childId)
                return SpecialistReportOutcome(report: report, meta: meta)
            }
        }

        let report = rules.generateSpecialistReport(sessions30d: sessions30d)
        let meta = makeMeta(start: start, source: .ruleBased, usedFallback: true)
        logDecision(kind: "specialistReport", meta: meta, output: "rules", childId: sessions30d.first?.childId)
        return SpecialistReportOutcome(report: report, meta: meta)
    }

    // MARK: - 11. Fatigue

    public func detectFatigue(audioMetrics: AudioMetricsInput, sessionDuration: TimeInterval) async -> FatigueDecisionOutcome {
        let start = Date()
        let (level, confidence) = rules.detectFatigue(audioMetrics: audioMetrics, sessionDuration: sessionDuration)
        let meta = makeMeta(start: start, source: .ruleBased, usedFallback: false)
        logDecision(kind: "detectFatigue", meta: meta, output: "\(level.rawValue)/\(confidence)", childId: nil)
        return FatigueDecisionOutcome(level: level, confidence: confidence, meta: meta)
    }

    // MARK: - 12. Custom phrase

    public func generateCustomPhrase(template: PhraseTemplate, context: [String: String]) async -> CustomPhraseOutcome {
        let start = Date()
        let phrase = rules.generateCustomPhrase(template: template, context: context)
        let meta = makeMeta(start: start, source: .ruleBased, usedFallback: false)
        logDecision(kind: "customPhrase:\(template.rawValue)", meta: meta, output: phrase.prefix(40).description, childId: nil)
        return CustomPhraseOutcome(phrase: phrase, meta: meta)
    }

    // MARK: - Helpers

    private func makeMeta(start: Date, source: LLMDecisionSource, usedFallback: Bool) -> LLMDecisionMeta {
        let elapsed = Int(Date().timeIntervalSince(start) * 1000)
        let modelId: String?
        switch source {
        case .onDevice:    modelId = LLMInferenceActor.modelId
        case .hfInference: modelId = HFInferenceClient.modelVikhrNemo
        case .ruleBased:   modelId = nil
        }
        return LLMDecisionMeta(source: source, latencyMs: elapsed, usedFallback: usedFallback, modelId: modelId)
    }

    private func logDecision(kind: String, meta: LLMDecisionMeta, output: String, childId: String?) {
        let record = LLMDecisionLogRecord(
            id: UUID().uuidString,
            childId: childId,
            decisionType: kind,
            inputHash: "n/a",
            output: output,
            modelId: meta.modelId,
            usedFallback: meta.usedFallback,
            latencyMs: meta.latencyMs,
            createdAt: Date()
        )
        Task { [logRepository] in
            try? await logRepository.save(record)
        }
        HSLogger.llm.debug("Decision \(kind) via \(meta.source.rawValue) in \(meta.latencyMs)ms (fallback=\(meta.usedFallback))")
    }

    private func progressJSON(_ map: [String: Double]) -> String {
        (try? String(data: JSONSerialization.data(withJSONObject: map), encoding: .utf8)) ?? "{}"
    }

    private func sessionsJSON(_ sessions: [SessionSummaryInput]) -> String {
        let arr = sessions.map { s -> [String: Any] in
            [
                "sound": s.targetSound,
                "stage": s.stage.rawValue,
                "total": s.totalAttempts,
                "correct": s.correctAttempts,
                "rate": Int((s.successRate * 100).rounded())
            ]
        }
        return (try? String(data: JSONSerialization.data(withJSONObject: arr), encoding: .utf8)) ?? "[]"
    }
}

// MARK: - withTimeout helper

private func withTimeout<T: Sendable>(
    ms: Int,
    _ work: @Sendable @escaping () async -> T?
) async -> T? {
    let nanos = UInt64(ms) * 1_000_000
    return await withTaskGroup(of: T?.self, returning: T?.self) { group in
        group.addTask { await work() }
        group.addTask {
            try? await Task.sleep(nanoseconds: nanos)
            return nil
        }
        let first = await group.next() ?? nil
        group.cancelAll()
        return first ?? nil
    }
}

// MARK: - JSONParser

private enum JSONParser {

    static func parseParentSummary(_ text: String) -> ParentSummary? {
        guard let data = extractJSON(text) else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let summary = obj["parent_summary"] as? String ?? obj["summaryText"] as? String
        let task = obj["home_task"] as? String ?? obj["homeTask"] as? String
        let tone = obj["tone"] as? String ?? "supportive"
        guard let s = summary, let t = task else { return nil }
        return ParentSummary(summaryText: s, homeTask: t, tone: tone)
    }

    static func parseContentRecommendation(_ text: String) -> ContentRecommendation? {
        guard let data = extractJSON(text) else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let ids = obj["pack_ids"] as? [String] ?? []
        let rationale = obj["rationale"] as? String ?? ""
        guard !ids.isEmpty else { return nil }
        return ContentRecommendation(packIds: ids, rationale: rationale)
    }

    static func parseSpecialistReport(_ text: String) -> SpecialistReport? {
        guard let data = extractJSON(text) else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let headline = obj["headline"] as? String ?? ""
        let strengths = obj["strengths"] as? [String] ?? []
        let weaknesses = obj["weaknesses"] as? [String] ?? []
        let recommendations = obj["recommendations"] as? [String] ?? []
        let next = obj["next_milestone"] as? String ?? ""
        guard !headline.isEmpty else { return nil }
        return SpecialistReport(
            headline: headline,
            strengths: strengths,
            weaknesses: weaknesses,
            recommendations: recommendations,
            nextMilestone: next
        )
    }

    /// Extract the first {...} block from potentially-noisy LLM output.
    static func extractJSON(_ text: String) -> Data? {
        guard let firstBrace = text.firstIndex(of: "{"),
              let lastBrace = text.lastIndex(of: "}"),
              firstBrace < lastBrace else { return nil }
        let slice = text[firstBrace...lastBrace]
        return String(slice).data(using: .utf8)
    }
}
