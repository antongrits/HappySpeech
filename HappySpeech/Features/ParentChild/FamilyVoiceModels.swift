import Foundation

// MARK: - FamilyVoiceMode

enum FamilyVoiceMode: Equatable, Sendable {
    case recorder
    case split
}

// MARK: - RecordingState

enum RecordingState: Equatable, Sendable {
    case idle
    case recording
    case playingBack
    case error(String)

    static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.recording, .recording), (.playingBack, .playingBack):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - RecordingItem (ViewModel)

struct RecordingItemViewModel: Identifiable, Equatable, Sendable {
    let id: String
    let word: String
    let durationText: String
    let recordedAt: Date
    let audioFilePath: String
}

// MARK: - FamilyVoiceViewModel

struct FamilyVoiceViewModel: Equatable, Sendable {
    let mode: FamilyVoiceMode
    let recordingState: RecordingState
    let selectedWord: String
    let recordings: [RecordingItemViewModel]
    let currentScore: Float?
    let feedback: String?
    let canDone: Bool
    let waveformLevels: [Float]
    let liveTranscript: String?
    let showFeedback: Bool
    let feedbackIsCorrect: Bool
    let toastMessage: String?

    static func == (lhs: FamilyVoiceViewModel, rhs: FamilyVoiceViewModel) -> Bool {
        lhs.mode == rhs.mode &&
        lhs.recordingState == rhs.recordingState &&
        lhs.selectedWord == rhs.selectedWord &&
        lhs.recordings == rhs.recordings &&
        lhs.currentScore == rhs.currentScore &&
        lhs.feedback == rhs.feedback &&
        lhs.canDone == rhs.canDone &&
        lhs.showFeedback == rhs.showFeedback &&
        lhs.feedbackIsCorrect == rhs.feedbackIsCorrect &&
        lhs.toastMessage == rhs.toastMessage
    }
}

// MARK: - Namespace: FamilyVoiceModels

enum FamilyVoiceModels {

    // MARK: - Target Words

    static let targetWords: [String] = [
        String(localized: "parent_child.word.ball"),
        String(localized: "parent_child.word.dog"),
        String(localized: "parent_child.word.fish"),
        String(localized: "parent_child.word.balloon"),
        String(localized: "parent_child.word.cow"),
        String(localized: "parent_child.word.fox"),
        String(localized: "parent_child.word.car"),
        String(localized: "parent_child.word.cat"),
        String(localized: "parent_child.word.hand"),
        String(localized: "parent_child.word.boat")
    ]

    static let targetWordsRaw: [String] = [
        "мяч", "собака", "рыба", "шар", "корова",
        "лиса", "машина", "кот", "рука", "лодка"
    ]

    static let maxRecordings: Int = 20

    // MARK: - Requests

    struct FetchRecordingsRequest {
        let parentId: String
    }

    struct StartRecordingRequest {
        let word: String
        let parentId: String
    }

    struct StopRecordingRequest {
        let word: String
        let parentId: String
    }

    struct PlayRecordingRequest {
        let recordingId: String
    }

    struct DeleteRecordingRequest {
        let recordingId: String
    }

    struct StartChildRecordingRequest {
        let word: String
        let referenceRecordingId: String
    }

    struct StopChildRecordingRequest {
        let word: String
        let referenceRecordingId: String
    }

    struct SkipWordRequest {
        let currentWord: String
    }

    struct ResetSessionRequest {}

    struct NextWordRequest {
        let currentWord: String
    }

    // MARK: - Responses

    struct FetchRecordingsResponse {
        let recordings: [RecordingDTO]
    }

    struct RecordingStartedResponse {
        let word: String
    }

    struct RecordingStoppedResponse {
        let recording: RecordingDTO
        let isNew: Bool
    }

    struct PlaybackResponse {
        let success: Bool
        let errorMessage: String?
    }

    struct DeleteResponse {
        let success: Bool
        let deletedId: String
    }

    struct ChildScoringResponse {
        let score: Float
        let transcript: String?
        let word: String
    }

    struct WordChangedResponse {
        let newWord: String
    }

    struct ErrorResponse {
        let message: String
    }
}

// MARK: - RecordingDTO (Sendable)

struct RecordingDTO: Sendable, Equatable {
    let id: String
    let word: String
    let audioFilePath: String
    let recordedAt: Date
    let durationSeconds: Double
    let parentProfileId: String
}
