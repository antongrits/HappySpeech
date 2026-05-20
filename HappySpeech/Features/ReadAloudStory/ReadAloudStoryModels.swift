import Foundation

// MARK: - ReadAloudStoryModels (Clean Swift: Models)
//
// v31 Волна D Ф.1 — «Слушай и понимай».
//
// Цель: закрыть Khan Academy Kids gap (G-03) — короткая read-aloud история
// с вопросами на понимание. Расширение существующих модулей Storytelling /
// Retelling: здесь ребёнок СЛУШАЕТ, а не рассказывает.
//
// Источники:
//  • G-03 (research v31): «Read-aloud books + comprehension Qs» — Khan Academy
//    Kids ~300 книг. Образовательный стандарт раннего чтения.
//  • Методика Левиной/Филичёвой-Чиркиной по импрессивной речи —
//    понимание текста (а не отдельной инструкции, как в ComprehensionDetective).
//
// Контент:
//  • Bundled JSON `pack_readaloud_stories.json` — 20 историй × 3 вопроса.
//  • TTS: AVSpeechSynthesizer ru-RU «Milena» (см. BedtimeModeWorker, тот же
//    pattern), с подсветкой текущего предложения через
//    `speechSynthesizer(_:willSpeakRangeOfSpeechString:utterance:)`.
//
// COPPA: контент полностью offline, никаких сетевых вызовов.

// MARK: - ReadAloudQuestion

/// Один вопрос на понимание. 4 варианта, индекс правильного.
public struct ReadAloudQuestion: Identifiable, Sendable, Equatable, Codable {
    public let id: String
    public let text: String
    public let options: [String]
    public let correctIndex: Int

    public init(id: String, text: String, options: [String], correctIndex: Int) {
        self.id = id
        self.text = text
        self.options = options
        self.correctIndex = correctIndex
    }

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case options
        case correctIndex
    }
}

// MARK: - ReadAloudStory

/// Короткая история для чтения вслух (4–6 предложений) + вопросы.
public struct ReadAloudStory: Identifiable, Sendable, Equatable, Codable {
    public let id: String
    public let title: String
    public let sentences: [String]
    public let questions: [ReadAloudQuestion]

    public init(
        id: String,
        title: String,
        sentences: [String],
        questions: [ReadAloudQuestion]
    ) {
        self.id = id
        self.title = title
        self.sentences = sentences
        self.questions = questions
    }
}

// MARK: - ReadAloudStage

/// Состояние сессии: чтение → переход → квиз → итоги.
public enum ReadAloudStage: Sendable, Equatable {
    case reading(currentSentenceIndex: Int)
    case readingPaused(currentSentenceIndex: Int)
    case quiz(questionIndex: Int)
    case summary
}

// MARK: - ReadAloudStoryModels namespace

enum ReadAloudStoryModels {

    // MARK: Start

    enum Start {
        struct Request: Sendable {
            let childId: String
            /// Если задан — пропустить указанную историю (рестарт сценария).
            let excludeStoryId: String?
        }

        struct Response: Sendable {
            let story: ReadAloudStory
        }

        struct ViewModel: Sendable {
            let title: String
            let storyId: String
            let sentences: [String]
            let totalQuestions: Int
            let firstSentenceLabel: String
        }
    }

    // MARK: NextSentence

    enum NextSentence {
        struct Response: Sendable {
            let stage: ReadAloudStage
            let progressLabel: String
            let progressFraction: Double
        }

        struct ViewModel: Sendable {
            let stage: ReadAloudStage
            let progressLabel: String
            let progressFraction: Double
            /// Индекс предложения, которое сейчас читается (или последнее) —
            /// `nil`, когда стадия не `reading`.
            let highlightedSentenceIndex: Int?
        }
    }

    // MARK: StartQuiz

    enum StartQuiz {
        struct Response: Sendable {
            let question: ReadAloudQuestion
            let questionIndex: Int
            let totalQuestions: Int
        }

        struct ViewModel: Sendable {
            let prompt: String
            let options: [OptionViewModel]
            let progressLabel: String
            let progressFraction: Double
            let accessibilityLabel: String
        }

        struct OptionViewModel: Identifiable, Sendable, Equatable {
            let id: Int
            let label: String
        }
    }

    // MARK: Answer

    enum Answer {
        struct Request: Sendable {
            let optionIndex: Int
        }

        struct Response: Sendable {
            let wasCorrect: Bool
            let correctIndex: Int
            let isFinished: Bool
            let nextQuestion: ReadAloudQuestion?
            let nextQuestionIndex: Int?
            let totalQuestions: Int
            let correctCount: Int
        }

        struct ViewModel: Sendable {
            let wasCorrect: Bool
            let feedbackText: String
            let isFinished: Bool
            let nextQuestion: StartQuiz.ViewModel?
            let summary: SummaryViewModel?
        }

        struct SummaryViewModel: Sendable {
            let title: String
            let scoreText: String
            let accuracyFraction: Double
            let encouragement: String
        }
    }
}
