import Foundation

// MARK: - ListenAndChoose VIP Models

/// Уровень сложности раунда — задаёт визуальную плотность сетки и
/// (если seed-данные позволяют) фонетический критерий выбора слов.
///
/// Маппинг номера вопроса → уровня (см. `tier(for:)`):
///   Q1–3 → easy   (2 варианта, в идеале — звук в начале слова)
///   Q4–6 → medium (3 варианта, в идеале — в середине)
///   Q7–8 → hard   (4 варианта, в идеале — в конце)
public enum ListenAndChooseDifficulty: Sendable, Equatable, Hashable {
    case easy
    case medium
    case hard

    /// Тиерное правило сложности на основе 1-based номера вопроса в сессии.
    public static func tier(for questionNumber: Int) -> ListenAndChooseDifficulty {
        switch questionNumber {
        case ..<4:  return .easy
        case 4...6: return .medium
        default:    return .hard
        }
    }

    /// Сколько вариантов ответа показывать.
    public var optionCount: Int {
        switch self {
        case .easy:   return 2
        case .medium: return 3
        case .hard:   return 4
        }
    }

    /// Ключ локализованной строки (Q3.6) для бейджа в карточке вопроса.
    public var titleKey: String {
        switch self {
        case .easy:   return "listen.difficulty.tier1"
        case .medium: return "listen.difficulty.tier2"
        case .hard:   return "listen.difficulty.tier3"
        }
    }

    /// Кол-во заполненных «звёзд» в бейдже.
    public var starCount: Int {
        switch self {
        case .easy:   return 1
        case .medium: return 2
        case .hard:   return 3
        }
    }
}

enum ListenAndChooseModels {

    // MARK: LoadRound
    enum LoadRound {
        struct Request {
            let soundTarget: String
            let difficulty: Int
        }
        struct Response {
            let targetWord: String
            let options: [OptionItem]
            let correctIndex: Int
            let audioAsset: String?
            /// Optional short hint shown to the child (e.g. "Слушай звук «С» в начале слова!").
            let hint: String?
            /// 1-based index of the current question inside the session (for progress UI).
            let questionNumber: Int
            /// Total number of unique questions in this session (not counting retry passes).
            let totalQuestions: Int
            /// True if this round is a retry of a previously wrong answer.
            let isRetry: Bool
            /// Уровень сложности раунда (см. `ListenAndChooseDifficulty.tier(for:)`).
            let difficulty: ListenAndChooseDifficulty

            init(
                targetWord: String,
                options: [OptionItem],
                correctIndex: Int,
                audioAsset: String?,
                hint: String? = nil,
                questionNumber: Int = 1,
                totalQuestions: Int = 1,
                isRetry: Bool = false,
                difficulty: ListenAndChooseDifficulty = .easy
            ) {
                self.targetWord = targetWord
                self.options = options
                self.correctIndex = correctIndex
                self.audioAsset = audioAsset
                self.hint = hint
                self.questionNumber = questionNumber
                self.totalQuestions = totalQuestions
                self.isRetry = isRetry
                self.difficulty = difficulty
            }
        }
        struct ViewModel {
            let targetWord: String
            let options: [OptionViewModel]
            let correctIndex: Int
            let instructionText: String
            let hintText: String?
            let progressText: String?
            let isRetry: Bool
            /// Сложность раунда — рисуется как чип «Уровень N ★…» над вариантами.
            let difficulty: ListenAndChooseDifficulty
            /// Готовая локализованная строка для бейджа (например, «Уровень 2»).
            let difficultyTitle: String

            init(
                targetWord: String,
                options: [OptionViewModel],
                correctIndex: Int,
                instructionText: String,
                hintText: String? = nil,
                progressText: String? = nil,
                isRetry: Bool = false,
                difficulty: ListenAndChooseDifficulty = .easy,
                difficultyTitle: String = ""
            ) {
                self.targetWord = targetWord
                self.options = options
                self.correctIndex = correctIndex
                self.instructionText = instructionText
                self.hintText = hintText
                self.progressText = progressText
                self.isRetry = isRetry
                self.difficulty = difficulty
                self.difficultyTitle = difficultyTitle
            }
        }

        struct OptionItem: Sendable {
            let id: String
            let word: String
            let imageAsset: String?
        }
        struct OptionViewModel: Identifiable, Equatable {
            let id: String
            let word: String
            let imageSystemName: String
        }
    }

    // MARK: SubmitAttempt
    enum SubmitAttempt {
        struct Request {
            let selectedIndex: Int
            let correctIndex: Int
            let attemptsUsed: Int
            /// Optional response time in milliseconds, from TTS end to tap.
            let responseTimeMs: Int?

            init(
                selectedIndex: Int,
                correctIndex: Int,
                attemptsUsed: Int,
                responseTimeMs: Int? = nil
            ) {
                self.selectedIndex = selectedIndex
                self.correctIndex = correctIndex
                self.attemptsUsed = attemptsUsed
                self.responseTimeMs = responseTimeMs
            }
        }
        struct Response {
            let isCorrect: Bool
            let isFinalAttempt: Bool
            let score: Float
            let shouldRevealAnswer: Bool
            let correctIndex: Int
            /// Current streak of correct answers in a row.
            let currentStreak: Int
            /// Optional short tip if the answer was wrong (e.g. acoustic focus cue).
            let hint: String?

            init(
                isCorrect: Bool,
                isFinalAttempt: Bool,
                score: Float,
                shouldRevealAnswer: Bool,
                correctIndex: Int,
                currentStreak: Int = 0,
                hint: String? = nil
            ) {
                self.isCorrect = isCorrect
                self.isFinalAttempt = isFinalAttempt
                self.score = score
                self.shouldRevealAnswer = shouldRevealAnswer
                self.correctIndex = correctIndex
                self.currentStreak = currentStreak
                self.hint = hint
            }
        }
        struct ViewModel {
            let isCorrect: Bool
            let feedbackText: String
            let shouldRevealAnswer: Bool
            let correctIndex: Int
            let finalScore: Float?
            let streakText: String?
            let hintText: String?

            init(
                isCorrect: Bool,
                feedbackText: String,
                shouldRevealAnswer: Bool,
                correctIndex: Int,
                finalScore: Float?,
                streakText: String? = nil,
                hintText: String? = nil
            ) {
                self.isCorrect = isCorrect
                self.feedbackText = feedbackText
                self.shouldRevealAnswer = shouldRevealAnswer
                self.correctIndex = correctIndex
                self.finalScore = finalScore
                self.streakText = streakText
                self.hintText = hintText
            }
        }
    }

    // MARK: ReplayWord
    /// Use case: replays the current target word via TTS (ru-RU, slow rate) so the
    /// child can re-listen without losing attempts.
    enum ReplayWord {
        struct Request: Sendable {}
        struct Response: Sendable {
            let targetWord: String
            let isPlaying: Bool
        }
        struct ViewModel: Sendable {
            let targetWord: String
            let isPlaying: Bool
        }
    }
}
