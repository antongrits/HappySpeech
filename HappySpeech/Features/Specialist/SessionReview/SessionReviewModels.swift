import Foundation

// MARK: - SessionReviewModels
//
// VIP models for the specialist "Session review" screen. Lets the specialist
// step through every attempt of a concrete session, playback the child's
// recording, and override the auto-computed score with a manual score.

enum SessionReviewModels {

    // MARK: LoadSession
    enum LoadSession {
        struct Request { let sessionId: String }
        struct Response {
            let session: SessionDTO
            let attemptRows: [AttemptReviewRow]
        }
        struct ViewModel: Equatable {
            let titleText: String
            let rows: [AttemptReviewRow]
            let summary: SessionReviewSummary
        }
    }

    // MARK: SetManualScore
    enum SetManualScore {
        struct Request {
            let sessionId: String
            let attemptId: String
            let manualScore: Double
        }
        struct Response {
            let attemptRows: [AttemptReviewRow]
            let summary: SessionReviewSummary
        }
        struct ViewModel: Equatable {
            let rows: [AttemptReviewRow]
            let summary: SessionReviewSummary
        }
    }

    // MARK: FinalizeReview
    enum FinalizeReview {
        struct Request {
            let sessionId: String
            let specialistNotes: String
        }
        struct Response { let savedAt: Date }
        struct ViewModel: Equatable {
            let confirmationText: String
        }
    }
}

// MARK: - Row

struct AttemptReviewRow: Identifiable, Sendable, Equatable, Hashable {
    let id: String
    let word: String
    let asrTranscript: String
    let autoScore: Double
    let manualScore: Double?
    let audioPath: String
    let isMarkedCorrect: Bool

    /// Effective score used for summaries: `manualScore` wins over `autoScore`.
    var effectiveScore: Double { manualScore ?? autoScore }
}

struct SessionReviewSummary: Sendable, Equatable {
    let totalAttempts: Int
    let markedCorrect: Int
    let averageEffectiveScore: Double
    let disagreementCount: Int   // specialist overrode auto — count of such rows
}
