import Foundation
import PencilKit

// MARK: - LetterTracing VIP Models

enum LetterTracingModels {

    // MARK: LoadExercise

    enum LoadExercise {
        struct Request {
            let targetLetter: String
            let difficulty: Int
        }
        struct Response {
            let targetLetter: String
            let promptText: String
            let roundIndex: Int
            let totalRounds: Int
        }
        struct ViewModel {
            let targetLetter: String
            let instructionText: String
            let progressText: String
            let roundIndex: Int
            let totalRounds: Int
        }
    }

    // MARK: SubmitDrawing

    enum SubmitDrawing {
        struct Request {
            let drawing: PKDrawing
            let targetLetter: String
            let drawingDuration: TimeInterval
        }
        struct Response {
            let recognizedLetter: String?
            let targetLetter: String
            let recognitionScore: Double
            let coverageScore: Double
            let speedScore: Double
            let finalScore: Double
            let isCorrect: Bool
        }
        struct ViewModel {
            let feedbackText: String
            let scorePercent: Int
            let isCorrect: Bool
            let recognizedText: String?
            let canRetry: Bool
        }
    }

    // MARK: ResetCanvas

    enum ResetCanvas {
        struct Request {}
        struct Response {}
        struct ViewModel {}
    }

    // MARK: CompleteSession

    enum CompleteSession {
        struct Request {}
        struct Response {
            let averageScore: Double
            let correctCount: Int
            let totalRounds: Int
        }
        struct ViewModel {
            let summaryText: String
            let finalScore: Float
        }
    }
}
