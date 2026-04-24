import Foundation

// MARK: - ListenAndChoose VIP Models

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

            init(
                targetWord: String,
                options: [OptionItem],
                correctIndex: Int,
                audioAsset: String?,
                hint: String? = nil,
                questionNumber: Int = 1,
                totalQuestions: Int = 1,
                isRetry: Bool = false
            ) {
                self.targetWord = targetWord
                self.options = options
                self.correctIndex = correctIndex
                self.audioAsset = audioAsset
                self.hint = hint
                self.questionNumber = questionNumber
                self.totalQuestions = totalQuestions
                self.isRetry = isRetry
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

            init(
                targetWord: String,
                options: [OptionViewModel],
                correctIndex: Int,
                instructionText: String,
                hintText: String? = nil,
                progressText: String? = nil,
                isRetry: Bool = false
            ) {
                self.targetWord = targetWord
                self.options = options
                self.correctIndex = correctIndex
                self.instructionText = instructionText
                self.hintText = hintText
                self.progressText = progressText
                self.isRetry = isRetry
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
