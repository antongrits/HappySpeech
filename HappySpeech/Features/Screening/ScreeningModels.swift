import Foundation

// MARK: - ScreeningModels
//
// VIP Request/Response/ViewModel for the initial diagnostic flow.
//
// Methodology (source: HappySpeech/ResearchDocs/therapy-stages.md):
// A screening consists of 20-30 prompts grouped into four blocks —
//   A. Articulation imitation (8 prompts, one per sound group)
//   B. Word pronunciation per position (initial / medial / final) — 12 prompts
//   C. Minimal-pair discrimination (5 prompts)
//   D. Breathing / duration hold (3 prompts)
// The interactor scores each prompt 0…1 and aggregates the results into a
// `ScreeningOutcome` that maps each target sound to a recommendation
// (`.normal`, `.monitor`, `.intervention`).

enum ScreeningModels {

    // MARK: StartScreening
    enum StartScreening {
        struct Request {
            let childId: String
            let childAge: Int
        }
        struct Response {
            let prompts: [ScreeningPrompt]
            let totalBlocks: Int
        }
        struct ViewModel: Equatable {
            let prompts: [ScreeningPrompt]
            let progressText: String
            let estimatedMinutes: Int
        }
    }

    // MARK: SubmitAnswer
    enum SubmitAnswer {
        struct Request {
            let promptId: String
            let score: Float          // 0.0 … 1.0
            let attemptCount: Int
        }
        struct Response {
            let isBlockComplete: Bool
            let isScreeningComplete: Bool
            let currentPromptIndex: Int
        }
        struct ViewModel: Equatable {
            let nextPromptIndex: Int?
            let shouldShowBlockTransition: Bool
            let shouldShowSummary: Bool
        }
    }

    // MARK: FinishScreening
    enum FinishScreening {
        struct Request { let childId: String }
        struct Response {
            let outcome: ScreeningOutcome
        }
        struct ViewModel: Equatable {
            let outcomeSummary: String
            let perSoundVerdicts: [SoundVerdictViewModel]
            let recommendedSessionMinutes: Int
            let priorityTargetSounds: [String]
        }
    }
}

// MARK: - ScreeningBlock

enum ScreeningBlock: String, Sendable, CaseIterable {
    case articulationImitation = "articulation"
    case wordPronunciation     = "word"
    case minimalPairs          = "minimal_pairs"
    case breathingDuration     = "breathing"

    var title: String {
        switch self {
        case .articulationImitation: return String(localized: "screening.block.articulation")
        case .wordPronunciation:     return String(localized: "screening.block.word")
        case .minimalPairs:          return String(localized: "screening.block.minimal_pairs")
        case .breathingDuration:     return String(localized: "screening.block.breathing")
        }
    }
}

// MARK: - ScreeningPrompt

struct ScreeningPrompt: Identifiable, Sendable, Equatable, Hashable {
    let id: String
    let block: ScreeningBlock
    let targetSound: String
    let stimulus: String        // слово / фраза / название упражнения
    let imageAsset: String?
    let referenceAudio: String?
    let acceptableHoldSeconds: Double?
}

// MARK: - Verdict

enum SoundVerdict: String, Sendable, Codable {
    /// Норма — звук произносится соответственно возрасту.
    case normal
    /// Наблюдение — лёгкие искажения, стоит следить.
    case monitor
    /// Требуется вмешательство — систематические ошибки, назначить уроки.
    case intervention

    public var displayKey: String {
        switch self {
        case .normal:       return "screening.verdict.normal"
        case .monitor:      return "screening.verdict.monitor"
        case .intervention: return "screening.verdict.intervention"
        }
    }
}

struct SoundVerdictViewModel: Identifiable, Equatable, Hashable {
    var id: String { sound }
    let sound: String
    let verdict: SoundVerdict
    let confidencePercent: Int
    let exampleWord: String?
}

// MARK: - Outcome

/// Aggregated result of a full screening pass. Persisted alongside the child
/// profile; re-screening in 2–4 weeks generates a fresh `ScreeningOutcome`.
struct ScreeningOutcome: Sendable, Codable, Equatable {
    let childId: String
    let completedAt: Date
    let perSound: [String: SoundVerdict]
    /// Sounds recommended as daily targets (verdict == .intervention),
    /// sorted by severity (lowest confidence first).
    let priorityTargetSounds: [String]
    /// Суммарное время на одну ежедневную сессию (сек) — зависит от возраста
    /// и количества проблемных звуков.
    let recommendedSessionDurationSec: Int
    /// Начальный этап коррекции для каждого проблемного звука.
    let initialStagePerSound: [String: String]

    public init(
        childId: String,
        completedAt: Date,
        perSound: [String: SoundVerdict],
        priorityTargetSounds: [String],
        recommendedSessionDurationSec: Int,
        initialStagePerSound: [String: String]
    ) {
        self.childId = childId
        self.completedAt = completedAt
        self.perSound = perSound
        self.priorityTargetSounds = priorityTargetSounds
        self.recommendedSessionDurationSec = recommendedSessionDurationSec
        self.initialStagePerSound = initialStagePerSound
    }
}
