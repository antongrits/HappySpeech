import Foundation

// MARK: - ScreeningModels
//
// VIP Request/Response/ViewModel for the initial diagnostic flow.
//
// Methodology (source: HappySpeech/ResearchDocs/therapy-stages.md):
// A screening covers 10 target phonemes in a single-word format:
//   С, Ш, З, Ж, Р, Л, Ч, Щ, Ц, К
// The interactor scores each recording 0…1 and aggregates the results into a
// `ScreeningOutcome` that maps each target sound to a recommendation
// (`.normal`, `.monitor`, `.intervention`).
//
// Adaptive early stop: if 2 consecutive scores < 0.40 → terminate early.

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
            let lyalyaPhrase: String
        }
        struct ViewModel: Equatable {
            let prompts: [ScreeningPrompt]
            let progressText: String
            let estimatedMinutes: Int
            let lyalyaPhrase: String
        }
    }

    // MARK: PrepareStage

    enum PrepareStage {
        struct Request {
            let stageIndex: Int
        }
        struct Response {
            let stageIndex: Int
            let totalStages: Int
            let prompt: ScreeningPrompt
            let lyalyaPhrase: String
            let canRecord: Bool
        }
        struct ViewModel: Equatable {
            let stageIndex: Int
            let totalStages: Int
            let progressFraction: Double
            let targetWord: String
            let targetSoundHint: String
            let imageAsset: String?
            let lyalyaPhrase: String
            let showRecordButton: Bool
        }
    }

    // MARK: StartRecording

    enum StartRecording {
        struct Request {
            let stageIndex: Int
        }
        struct Response {
            let stageIndex: Int
            let maxDurationSec: Double
        }
        struct ViewModel: Equatable {
            let stageIndex: Int
            let isRecording: Bool
            let timerLabelText: String
        }
    }

    // MARK: StopRecording

    enum StopRecording {
        struct Request {
            let stageIndex: Int
        }
        // Response delivered via SubmitAnswer after scoring completes
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
            /// Adaptive-stop был вызван досрочно (не последний промпт, но 2 wrong подряд)
            let adaptiveStopTriggered: Bool
        }
        struct ViewModel: Equatable {
            let nextPromptIndex: Int?
            let shouldShowBlockTransition: Bool
            let shouldShowSummary: Bool
            let adaptiveStopMessage: String?
        }
    }

    // MARK: ReplayAudio

    enum ReplayAudio {
        struct Request {
            let stageIndex: Int
            let referenceAudioAsset: String?
        }
        // No response — fire and forget
    }

    // MARK: FinishScreening

    enum FinishScreening {
        struct Request { let childId: String }
        struct Response {
            let outcome: ScreeningOutcome
            /// Скрининг был прерван адаптивно (не дошёл до конца)
            let wasAdaptiveStopped: Bool
            let testedSoundsCount: Int
            let totalSoundsCount: Int
            let lyalyaFinishPhrase: String
        }
        struct ViewModel: Equatable {
            let outcomeSummary: String
            let perSoundVerdicts: [SoundVerdictViewModel]
            let recommendedSessionMinutes: Int
            let priorityTargetSounds: [String]
            let wasAdaptiveStopped: Bool
            let testedLabel: String
            let lyalyaFinishPhrase: String
        }
    }

    // MARK: RecordingError

    struct RecordingError {
        let errorMessage: String
        let canContinueWithoutRecording: Bool
    }

    // MARK: MicrophonePermission

    enum MicrophonePermission {
        struct Response {
            let isGranted: Bool
        }
        struct ViewModel: Equatable {
            let isGranted: Bool
            let deniedMessage: String?
        }
    }

    // MARK: CheckRescreening

    enum CheckRescreening {
        struct Request {
            let childId: String
        }
        struct Response {
            let isEligible: Bool
            let daysSinceLastScreening: Int?
            let previousOutcomeSummary: PreviousOutcomeSummary?
        }
        struct ViewModel: Equatable {
            let isEligible: Bool
            let warningMessage: String?
            let previousSummaryText: String?
        }
    }

    // MARK: PreviousOutcomeSummary

    struct PreviousOutcomeSummary: Equatable, Sendable {
        let completedAt: Date
        let severity: String
        let problematicSounds: [String]
        let daysSince: Int
    }

    // MARK: CompleteRequest

    /// Финальный «акт сдачи»: после того, как презентер сформировал ViewModel и UI
    /// показал summary, родитель/специалист подтверждает запись результата. Этот
    /// запрос несёт в себе уже агрегированные поля для сохранения в Realm.
    struct CompleteRequest: Sendable {
        let childId: String
        /// "mild" | "moderate" | "severe" — выводится из количества звуков с
        /// `intervention`-verdict (см. ScreeningOutcomeObject header).
        let severity: String
        /// Список проблемных звуков (verdict == .intervention), отсортированный
        /// по убыванию серьёзности.
        let problematicSounds: [String]
        /// Идентификаторы рекомендованных контент-паков
        /// (например, ["sound_r_pack", "sound_sh_pack"]).
        let recommendedPacks: [String]
        /// Свободные заметки. По умолчанию — пустая строка.
        let notes: String
        /// Признак повторного скрининга (не первый раз).
        let isRescreening: Bool
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
