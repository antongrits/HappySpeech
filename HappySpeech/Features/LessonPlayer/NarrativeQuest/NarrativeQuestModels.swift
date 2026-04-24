import Foundation
import Observation

// MARK: - NarrativeQuestModels
//
// VIP-модели для «Квеста с Лялей». Ребёнок проживает мини-историю
// из четырёх этапов, на каждом этапе слушает нарратив, произносит
// ключевое слово и собирает награду-эмодзи. В конце — праздник
// и звёздный скор.

enum NarrativeQuestModels {

    // MARK: - LoadQuest

    enum LoadQuest {
        struct Request: Sendable {
            let soundTarget: String
            let childName: String
        }
        struct Response: Sendable {
            let script: NarrativeQuestScript
        }
        struct ViewModel: Sendable {
            let questTitle: String
            let totalStages: Int
            let finalRewardEmoji: String
            let introNarration: String
        }
    }

    // MARK: - StartStage

    enum StartStage {
        struct Request: Sendable {
            let stageIndex: Int
        }
        struct Response: Sendable {
            let stage: NarrativeQuestStage
            let stageNumber: Int
            let totalStages: Int
            let progressFraction: Double
        }
        struct ViewModel: Sendable {
            let narration: String
            let task: String
            let targetWord: String
            let hint: String
            let rewardEmoji: String
            let stageNumber: Int
            let totalStages: Int
            let progressFraction: Double
        }
    }

    // MARK: - RecordWord

    enum RecordWord {
        struct Request: Sendable {
            let stageIndex: Int
        }
        struct Response: Sendable {
            let isListening: Bool
        }
        struct ViewModel: Sendable {
            let isListening: Bool
            let micLabel: String
        }
    }

    // MARK: - EvaluateWord

    enum EvaluateWord {
        struct Request: Sendable {
            let transcript: String
            let confidence: Float
        }
        struct Response: Sendable {
            let score: Float
            let passed: Bool
            let rewardEmoji: String
            let successNarration: String
        }
        struct ViewModel: Sendable {
            let feedbackText: String
            let feedbackSuccess: Bool
            let rewardEmoji: String
            let showSuccessOverlay: Bool
            let score: Float
        }
    }

    // MARK: - AdvanceStage

    enum AdvanceStage {
        struct Request: Sendable {}
        struct Response: Sendable {
            let nextStageIndex: Int?
            let collectedEmojis: [String]
            let progressFraction: Double
            let stageNumber: Int
        }
        struct ViewModel: Sendable {
            let collectedEmojis: [String]
            let progressFraction: Double
            let stageNumber: Int
            let isLast: Bool
        }
    }

    // MARK: - CompleteQuest

    enum CompleteQuest {
        struct Request: Sendable {}
        struct Response: Sendable {
            let averageScore: Float
            let starsEarned: Int
            let collectedEmojis: [String]
            let finalRewardEmoji: String
            let finalMessage: String
        }
        struct ViewModel: Sendable {
            let starsEarned: Int
            let collectedEmojis: [String]
            let finalRewardEmoji: String
            let completionMessage: String
            let scoreLabel: String
            let normalizedScore: Float
        }
    }
}

// MARK: - Domain

/// Один этап квеста: нарратив → задача → целевое слово → успех-нарратив.
struct NarrativeQuestStage: Sendable, Identifiable, Hashable {
    let id: UUID
    let stageNumber: Int
    let narration: String
    let task: String
    let targetWord: String
    let targetSoundGroup: String
    let successNarration: String
    let rewardEmoji: String
    let hint: String

    init(
        id: UUID = UUID(),
        stageNumber: Int,
        narration: String,
        task: String,
        targetWord: String,
        targetSoundGroup: String,
        successNarration: String,
        rewardEmoji: String,
        hint: String
    ) {
        self.id = id
        self.stageNumber = stageNumber
        self.narration = narration
        self.task = task
        self.targetWord = targetWord
        self.targetSoundGroup = targetSoundGroup
        self.successNarration = successNarration
        self.rewardEmoji = rewardEmoji
        self.hint = hint
    }
}

/// Сценарий квеста: набор из четырёх этапов под одну звуковую группу.
struct NarrativeQuestScript: Sendable, Hashable {
    let id: String
    let title: String
    let introNarration: String
    let stages: [NarrativeQuestStage]
    let finalRewardEmoji: String
    let finalMessage: String
}

// MARK: - Phase

/// Укрупнённые фазы UI. Управляет StoreBridge.
enum NarrativeQuestPhase: Sendable, Equatable {
    case loading
    case questIntro
    case stageNarration
    case recording
    case stageFeedback
    case questComplete
    case completed
}

// MARK: - Display store

/// @Observable store — единственный источник истины для View.
@Observable
@MainActor
final class NarrativeQuestDisplay {

    // Quest header
    var questTitle: String = ""
    var introNarration: String = ""
    var finalRewardEmoji: String = ""

    // Current stage
    var narration: String = ""
    var task: String = ""
    var targetWord: String = ""
    var hint: String = ""
    var rewardEmoji: String = ""

    // Progress
    var phase: NarrativeQuestPhase = .loading
    var stageNumber: Int = 0
    var totalStages: Int = 4
    var progressFraction: Double = 0

    // Recording
    var isListening: Bool = false
    var micLabel: String = ""

    // Feedback
    var feedbackText: String = ""
    var feedbackSuccess: Bool = false
    var showSuccessOverlay: Bool = false
    var lastScore: Float = 0

    // Final
    var starsEarned: Int = 0
    var scoreLabel: String = ""
    var completionMessage: String = ""
    var collectedEmojis: [String] = []

    // View → Interactor handshake: View видит finalScore и вызывает onComplete.
    var pendingFinalScore: Float?
}
