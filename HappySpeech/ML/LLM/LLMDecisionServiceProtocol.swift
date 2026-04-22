import Foundation

// MARK: - LLMDecisionServiceProtocol
// ==================================================================================
// Central "brain" of HappySpeech — 12 decision points across the app.
// Every method:
//   1. Tries an on-device LLM (Qwen2.5-1.5B via MLC) when the model is downloaded.
//   2. Falls back to the HF Inference API (Vikhr-Nemo-12B) — parent/specialist circuits only.
//   3. Falls back to a fully deterministic RuleBasedDecisionService — always available.
// All methods are `async` and return a result type (never throws) so the caller
// always has something usable. Latency budgets (master-plan v2 §19.5) are enforced
// inside LiveLLMDecisionService — if the LLM misses the budget, rule-based kicks in.
// ==================================================================================

public protocol LLMDecisionServiceProtocol: AnyObject, Sendable {

    // MARK: Model State
    var isOnDeviceModelReady: Bool { get async }
    var downloadProgress: Double { get async }

    // MARK: Decision Points (12)

    /// 1. Adaptive daily route for a child profile.
    func adaptiveRoutePlan(context: RoutePlanContext) async -> RouteDecisionOutcome

    /// 2. Generate a short therapeutic micro-story (narrative-quest template).
    func generateMicroStory(context: StoryContext) async -> StoryDecisionOutcome

    /// 3. Parent-facing session summary + homework hint.
    func generateParentSummary(session: SessionSummaryInput) async -> ParentSummaryDecisionOutcome

    /// 4. Encouragement phrase after an attempt (kid circuit — on-device or rules only).
    func pickEncouragementPhrase(context: AttemptContext) async -> EncouragementDecisionOutcome

    /// 5. Reward message when a milestone / streak unlocks a sticker.
    func pickReward(streak: Int, sessionType: SessionType) async -> RewardDecisionOutcome

    /// 6. Decide whether the session should end early (fatigue-aware).
    func decideFinishSession(fatigueLevel: Double, attempts: Int) async -> FinishDecisionOutcome

    /// 7. Adjust upcoming difficulty based on recent attempts.
    func adjustDifficulty(recentAttempts: [AttemptOutcome]) async -> DifficultyDecisionOutcome

    /// 8. Interpret / score an ASR attempt beyond raw confidence.
    func analyzeError(attempt: AttemptOutcome, target: String) async -> ErrorAnalysisDecisionOutcome

    /// 9. Recommend content packs based on profile + history.
    func recommendContent(profile: ChildProfileInput, history: [SessionSummaryInput]) async -> ContentRecommendationOutcome

    /// 10. Build a long-form specialist report (PDF-ready) from the last 30 days.
    func generateSpecialistReport(sessions30d: [SessionSummaryInput]) async -> SpecialistReportOutcome

    /// 11. Detect fatigue from audio metrics + session duration.
    func detectFatigue(audioMetrics: AudioMetricsInput, sessionDuration: TimeInterval) async -> FatigueDecisionOutcome

    /// 12. Generate an ad-hoc phrase from a template (warmup, parent tip, homework).
    func generateCustomPhrase(template: PhraseTemplate, context: [String: String]) async -> CustomPhraseOutcome
}

// MARK: - Decision Points — Input Types

public struct RoutePlanContext: Sendable {
    public let childId: String
    public let childName: String
    public let age: Int
    public let targetSound: String
    public let currentStage: CorrectionStage
    public let recentSuccessRate: Double
    public let fatigueLevel: FatigueLevel
    public let availableTemplates: [TemplateType]
    public let circuit: DecisionCircuit

    public init(
        childId: String,
        childName: String,
        age: Int,
        targetSound: String,
        currentStage: CorrectionStage,
        recentSuccessRate: Double,
        fatigueLevel: FatigueLevel,
        availableTemplates: [TemplateType],
        circuit: DecisionCircuit = .kid
    ) {
        self.childId = childId
        self.childName = childName
        self.age = age
        self.targetSound = targetSound
        self.currentStage = currentStage
        self.recentSuccessRate = recentSuccessRate
        self.fatigueLevel = fatigueLevel
        self.availableTemplates = availableTemplates
        self.circuit = circuit
    }
}

public struct StoryContext: Sendable {
    public let targetSound: String
    public let age: Int
    public let wordPool: [String]
    public let stage: CorrectionStage

    public init(targetSound: String, age: Int, wordPool: [String], stage: CorrectionStage) {
        self.targetSound = targetSound
        self.age = age
        self.wordPool = wordPool
        self.stage = stage
    }
}

public struct SessionSummaryInput: Sendable {
    public let sessionId: String
    public let childId: String
    public let childName: String
    public let age: Int
    public let targetSound: String
    public let stage: CorrectionStage
    public let totalAttempts: Int
    public let correctAttempts: Int
    public let errorWords: [String]
    public let durationSec: Int
    public let date: Date

    public init(
        sessionId: String,
        childId: String,
        childName: String,
        age: Int,
        targetSound: String,
        stage: CorrectionStage,
        totalAttempts: Int,
        correctAttempts: Int,
        errorWords: [String],
        durationSec: Int,
        date: Date
    ) {
        self.sessionId = sessionId
        self.childId = childId
        self.childName = childName
        self.age = age
        self.targetSound = targetSound
        self.stage = stage
        self.totalAttempts = totalAttempts
        self.correctAttempts = correctAttempts
        self.errorWords = errorWords
        self.durationSec = durationSec
        self.date = date
    }

    public var successRate: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(correctAttempts) / Double(totalAttempts)
    }
}

public struct AttemptContext: Sendable {
    public let childName: String
    public let word: String
    public let targetSound: String
    public let isCorrect: Bool
    public let streak: Int
    public let recentSuccessRate: Double

    public init(
        childName: String,
        word: String,
        targetSound: String,
        isCorrect: Bool,
        streak: Int,
        recentSuccessRate: Double
    ) {
        self.childName = childName
        self.word = word
        self.targetSound = targetSound
        self.isCorrect = isCorrect
        self.streak = streak
        self.recentSuccessRate = recentSuccessRate
    }
}

public struct AttemptOutcome: Sendable {
    public let word: String
    public let targetSound: String
    public let isCorrect: Bool
    public let asrTranscript: String
    public let asrConfidence: Double
    public let pronunciationScore: Double

    public init(
        word: String,
        targetSound: String,
        isCorrect: Bool,
        asrTranscript: String,
        asrConfidence: Double,
        pronunciationScore: Double
    ) {
        self.word = word
        self.targetSound = targetSound
        self.isCorrect = isCorrect
        self.asrTranscript = asrTranscript
        self.asrConfidence = asrConfidence
        self.pronunciationScore = pronunciationScore
    }
}

public struct ChildProfileInput: Sendable {
    public let id: String
    public let name: String
    public let age: Int
    public let targetSounds: [String]
    public let sensitivityLevel: Int
    public let progressSummary: [String: Double]

    public init(
        id: String,
        name: String,
        age: Int,
        targetSounds: [String],
        sensitivityLevel: Int,
        progressSummary: [String: Double]
    ) {
        self.id = id
        self.name = name
        self.age = age
        self.targetSounds = targetSounds
        self.sensitivityLevel = sensitivityLevel
        self.progressSummary = progressSummary
    }
}

public struct AudioMetricsInput: Sendable {
    public let averageAmplitude: Float
    public let silenceRatio: Float
    public let speakingRateWpm: Double
    public let attemptsPerMinute: Double

    public init(averageAmplitude: Float, silenceRatio: Float, speakingRateWpm: Double, attemptsPerMinute: Double) {
        self.averageAmplitude = averageAmplitude
        self.silenceRatio = silenceRatio
        self.speakingRateWpm = speakingRateWpm
        self.attemptsPerMinute = attemptsPerMinute
    }
}

public enum DecisionCircuit: String, Sendable {
    case kid, parent, specialist
}

public enum SessionType: String, Sendable {
    case daily, freePlay, homework, arZone, demo
}

public enum PhraseTemplate: String, Sendable {
    case warmup
    case parentTip
    case homework
    case transition
    case sessionComplete
}

// MARK: - Decision Points — Output Types

public enum LLMDecisionSource: String, Sendable, Codable {
    case onDevice, hfInference, ruleBased
}

public struct LLMDecisionMeta: Sendable, Codable {
    public let source: LLMDecisionSource
    public let latencyMs: Int
    public let usedFallback: Bool
    public let modelId: String?

    public init(source: LLMDecisionSource, latencyMs: Int, usedFallback: Bool, modelId: String?) {
        self.source = source
        self.latencyMs = latencyMs
        self.usedFallback = usedFallback
        self.modelId = modelId
    }
}

public struct RouteDecisionOutcome: Sendable {
    public let route: [RouteStepItem]
    public let sessionMaxDurationSec: Int
    public let meta: LLMDecisionMeta

    public init(route: [RouteStepItem], sessionMaxDurationSec: Int, meta: LLMDecisionMeta) {
        self.route = route
        self.sessionMaxDurationSec = sessionMaxDurationSec
        self.meta = meta
    }
}

public struct MicroStory: Sendable, Codable {
    public struct Gap: Sendable, Codable {
        public let sentenceIndex: Int
        public let word: String
        public let imageHint: String

        public init(sentenceIndex: Int, word: String, imageHint: String) {
            self.sentenceIndex = sentenceIndex
            self.word = word
            self.imageHint = imageHint
        }
    }
    public let sentences: [String]
    public let gaps: [Gap]

    public init(sentences: [String], gaps: [Gap]) {
        self.sentences = sentences
        self.gaps = gaps
    }
}

public struct StoryDecisionOutcome: Sendable {
    public let story: MicroStory
    public let meta: LLMDecisionMeta

    public init(story: MicroStory, meta: LLMDecisionMeta) {
        self.story = story
        self.meta = meta
    }
}

public struct ParentSummary: Sendable, Codable {
    public let summaryText: String
    public let homeTask: String
    public let tone: String

    public init(summaryText: String, homeTask: String, tone: String) {
        self.summaryText = summaryText
        self.homeTask = homeTask
        self.tone = tone
    }
}

public struct ParentSummaryDecisionOutcome: Sendable {
    public let summary: ParentSummary
    public let meta: LLMDecisionMeta

    public init(summary: ParentSummary, meta: LLMDecisionMeta) {
        self.summary = summary
        self.meta = meta
    }
}

public struct EncouragementDecisionOutcome: Sendable {
    public let message: String
    public let emoji: String
    public let meta: LLMDecisionMeta

    public init(message: String, emoji: String, meta: LLMDecisionMeta) {
        self.message = message
        self.emoji = emoji
        self.meta = meta
    }
}

public struct Reward: Sendable, Codable {
    public let title: String
    public let subtitle: String
    public let stickerId: String
    public let badgeId: String?

    public init(title: String, subtitle: String, stickerId: String, badgeId: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.stickerId = stickerId
        self.badgeId = badgeId
    }
}

public struct RewardDecisionOutcome: Sendable {
    public let reward: Reward
    public let meta: LLMDecisionMeta

    public init(reward: Reward, meta: LLMDecisionMeta) {
        self.reward = reward
        self.meta = meta
    }
}

public struct FinishDecisionOutcome: Sendable {
    public let shouldFinish: Bool
    public let reason: String
    public let meta: LLMDecisionMeta

    public init(shouldFinish: Bool, reason: String, meta: LLMDecisionMeta) {
        self.shouldFinish = shouldFinish
        self.reason = reason
        self.meta = meta
    }
}

public enum Difficulty: Int, Sendable, Codable {
    case easy = 1, medium = 2, hard = 3
}

public struct DifficultyDecisionOutcome: Sendable {
    public let difficulty: Difficulty
    public let delta: Int
    public let reason: String
    public let meta: LLMDecisionMeta

    public init(difficulty: Difficulty, delta: Int, reason: String, meta: LLMDecisionMeta) {
        self.difficulty = difficulty
        self.delta = delta
        self.reason = reason
        self.meta = meta
    }
}

public struct ErrorAnalysis: Sendable, Codable {
    public enum Category: String, Sendable, Codable {
        case soundDistortion, soundOmission, soundReplacement, hesitation, correct, uncertain
    }
    public let category: Category
    public let hint: String

    public init(category: Category, hint: String) {
        self.category = category
        self.hint = hint
    }
}

public struct ErrorAnalysisDecisionOutcome: Sendable {
    public let analysis: ErrorAnalysis
    public let meta: LLMDecisionMeta

    public init(analysis: ErrorAnalysis, meta: LLMDecisionMeta) {
        self.analysis = analysis
        self.meta = meta
    }
}

public struct ContentRecommendation: Sendable, Codable {
    public let packIds: [String]
    public let rationale: String

    public init(packIds: [String], rationale: String) {
        self.packIds = packIds
        self.rationale = rationale
    }
}

public struct ContentRecommendationOutcome: Sendable {
    public let recommendation: ContentRecommendation
    public let meta: LLMDecisionMeta

    public init(recommendation: ContentRecommendation, meta: LLMDecisionMeta) {
        self.recommendation = recommendation
        self.meta = meta
    }
}

public struct SpecialistReport: Sendable, Codable {
    public let headline: String
    public let strengths: [String]
    public let weaknesses: [String]
    public let recommendations: [String]
    public let nextMilestone: String

    public init(
        headline: String,
        strengths: [String],
        weaknesses: [String],
        recommendations: [String],
        nextMilestone: String
    ) {
        self.headline = headline
        self.strengths = strengths
        self.weaknesses = weaknesses
        self.recommendations = recommendations
        self.nextMilestone = nextMilestone
    }
}

public struct SpecialistReportOutcome: Sendable {
    public let report: SpecialistReport
    public let meta: LLMDecisionMeta

    public init(report: SpecialistReport, meta: LLMDecisionMeta) {
        self.report = report
        self.meta = meta
    }
}

public struct FatigueDecisionOutcome: Sendable {
    public let level: FatigueLevel
    public let confidence: Double
    public let meta: LLMDecisionMeta

    public init(level: FatigueLevel, confidence: Double, meta: LLMDecisionMeta) {
        self.level = level
        self.confidence = confidence
        self.meta = meta
    }
}

public struct CustomPhraseOutcome: Sendable {
    public let phrase: String
    public let meta: LLMDecisionMeta

    public init(phrase: String, meta: LLMDecisionMeta) {
        self.phrase = phrase
        self.meta = meta
    }
}
