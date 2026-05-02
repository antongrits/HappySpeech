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
            let tracingLevel: TracingLevel
            let hintState: HintState
            let strokeCount: Int
            let phonemeWord: String
        }
        struct ViewModel {
            let targetLetter: String
            let instructionText: String
            let progressText: String
            let roundIndex: Int
            let totalRounds: Int
            let tracingLevel: TracingLevel
            let hintState: HintState
            let strokeCount: Int
            let phonemeWord: String
            let voicePrompt: String
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
            let attemptNumber: Int
            let bestScore: Double
        }
        struct ViewModel {
            let feedbackText: String
            let scorePercent: Int
            let isCorrect: Bool
            let recognizedText: String?
            let canRetry: Bool
            let attemptNumber: Int
            let bestScorePercent: Int
            let voiceFeedback: String
        }
    }

    // MARK: ResetCanvas

    enum ResetCanvas {
        struct Request {}
        struct Response {}
        struct ViewModel {}
    }

    // MARK: RequestHint

    enum RequestHint {
        struct Request {
            let letter: String
        }
        struct Response {
            let hintState: HintState
            let hintDescription: String
        }
        struct ViewModel {
            let hintState: HintState
            let hintText: String
            let showStartDot: Bool
            let showDirectionArrow: Bool
            let showFullTemplate: Bool
        }
    }

    // MARK: CompleteSession

    enum CompleteSession {
        struct Request {}
        struct Response {
            let averageScore: Double
            let correctCount: Int
            let totalRounds: Int
            let achievedLetters: [String]
            let improvedLetters: [String]
        }
        struct ViewModel {
            let summaryText: String
            let finalScore: Float
            let achievedText: String
            let celebrationText: String
        }
    }

    // MARK: - Supporting Types

    /// Три прогрессивных уровня обводки.
    enum TracingLevel: Int, Sendable {
        /// Уровень 1: обводка поверх полного шаблона буквы.
        case overTemplate = 1
        /// Уровень 2: только точки направления (без полного шаблона).
        case dotsOnly = 2
        /// Уровень 3: свободное написание без подсказок.
        case freeWrite = 3

        var localizedTitle: String {
            switch self {
            case .overTemplate: return String(localized: "letter_tracing.level.template")
            case .dotsOnly: return String(localized: "letter_tracing.level.dots")
            case .freeWrite: return String(localized: "letter_tracing.level.free")
            }
        }
    }

    /// Состояние системы подсказок.
    enum HintState: Int, Sendable {
        /// Подсказок не запрошено.
        case none = 0
        /// Подсказка 1: анимированная точка начала штриха.
        case startPoint = 1
        /// Подсказка 2: анимированная стрелка направления.
        case direction = 2
        /// Подсказка 3: полупрозрачный шаблон поверх холста.
        case fullTemplate = 3

        /// Следующий уровень подсказки.
        var next: HintState {
            switch self {
            case .none: return .startPoint
            case .startPoint: return .direction
            case .direction: return .fullTemplate
            case .fullTemplate: return .fullTemplate
            }
        }
    }

    /// Запись прогресса освоения конкретной буквы.
    struct LetterProficiency: Sendable {
        let letter: String
        var attempts: Int
        var bestScore: Double
        var lastScore: Double
        var isAchieved: Bool

        init(letter: String) {
            self.letter = letter
            self.attempts = 0
            self.bestScore = 0
            self.lastScore = 0
            self.isAchieved = false
        }
    }
}
