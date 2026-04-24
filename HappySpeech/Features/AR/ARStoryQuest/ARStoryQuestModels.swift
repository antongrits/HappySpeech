import Foundation

// MARK: - ARStoryQuestModels
//
// VIP модели для игры «AR Story Quest» — 8-шагового нарративного приключения,
// где Ляля ведёт ребёнка через историю и на каждом шаге просит произнести
// целевое слово. Игра не использует ARKit: это SwiftUI + Audio + ASR квест
// с фронт-UI в стиле детского контура.

// MARK: - Quest definition

/// Один шаг нарративного квеста: нарратив + целевое слово + подсказка.
struct QuestStep: Sendable, Identifiable, Hashable {
    let id: String
    let stepNumber: Int          // 1…8
    let narration: String        // текст нарратива от Ляли
    let targetWord: String       // слово, которое ребёнок произносит
    let soundGroup: String       // "whistling" | "hissing" | "sonants" | "velar"
    let hint: String             // артикуляционная подсказка
    let rewardEmoji: String      // emoji после успеха
}

/// Квест — сценарий из 8 связных шагов.
struct QuestScript: Sendable, Hashable {
    let questId: String
    let title: String
    let steps: [QuestStep]       // ровно 8 шагов
}

// MARK: - Built-in scripts

extension QuestScript {

    /// «Космическое приключение» — дефолтный квест на первый прогон.
    /// Охватывает все 4 звуковые группы: свистящие, шипящие, соноры, заднеязычные.
    static let spaceAdventure = QuestScript(
        questId: "space_adventure",
        title: String(localized: "ar.quest.space.title"),
        steps: [
            QuestStep(
                id: "s1",
                stepNumber: 1,
                narration: String(localized: "ar.quest.space.s1.narration"),
                targetWord: String(localized: "ar.quest.space.s1.word"),
                soundGroup: "whistling",
                hint: String(localized: "ar.quest.space.s1.hint"),
                rewardEmoji: "🪐"
            ),
            QuestStep(
                id: "s2",
                stepNumber: 2,
                narration: String(localized: "ar.quest.space.s2.narration"),
                targetWord: String(localized: "ar.quest.space.s2.word"),
                soundGroup: "whistling",
                hint: String(localized: "ar.quest.space.s2.hint"),
                rewardEmoji: "☀️"
            ),
            QuestStep(
                id: "s3",
                stepNumber: 3,
                narration: String(localized: "ar.quest.space.s3.narration"),
                targetWord: String(localized: "ar.quest.space.s3.word"),
                soundGroup: "whistling",
                hint: String(localized: "ar.quest.space.s3.hint"),
                rewardEmoji: "🦓"
            ),
            QuestStep(
                id: "s4",
                stepNumber: 4,
                narration: String(localized: "ar.quest.space.s4.narration"),
                targetWord: String(localized: "ar.quest.space.s4.word"),
                soundGroup: "hissing",
                hint: String(localized: "ar.quest.space.s4.hint"),
                rewardEmoji: "🌟"
            ),
            QuestStep(
                id: "s5",
                stepNumber: 5,
                narration: String(localized: "ar.quest.space.s5.narration"),
                targetWord: String(localized: "ar.quest.space.s5.word"),
                soundGroup: "hissing",
                hint: String(localized: "ar.quest.space.s5.hint"),
                rewardEmoji: "💛"
            ),
            QuestStep(
                id: "s6",
                stepNumber: 6,
                narration: String(localized: "ar.quest.space.s6.narration"),
                targetWord: String(localized: "ar.quest.space.s6.word"),
                soundGroup: "sonants",
                hint: String(localized: "ar.quest.space.s6.hint"),
                rewardEmoji: "🐦"
            ),
            QuestStep(
                id: "s7",
                stepNumber: 7,
                narration: String(localized: "ar.quest.space.s7.narration"),
                targetWord: String(localized: "ar.quest.space.s7.word"),
                soundGroup: "sonants",
                hint: String(localized: "ar.quest.space.s7.hint"),
                rewardEmoji: "⚔️"
            ),
            QuestStep(
                id: "s8",
                stepNumber: 8,
                narration: String(localized: "ar.quest.space.s8.narration"),
                targetWord: String(localized: "ar.quest.space.s8.word"),
                soundGroup: "velar",
                hint: String(localized: "ar.quest.space.s8.hint"),
                rewardEmoji: "🏠"
            )
        ]
    )
}

// MARK: - VIP message types

/// Запросы от View → Interactor.
enum ARStoryQuestRequest: Sendable {
    case loadQuest(script: QuestScript)
    case startListening
    case stopListening
    case submitAttempt(transcript: String, confidence: Float)
    case advanceStep
    case restartQuest
    case dismiss
}

/// Ответы от Interactor → Presenter.
enum ARStoryQuestResponse: Sendable {
    case questLoaded(script: QuestScript, currentStep: QuestStep)
    case listeningStarted
    case listeningStopped
    case attemptEvaluated(score: Float, passed: Bool, feedback: String, stepEmoji: String)
    case stepAdvanced(step: QuestStep, isLast: Bool)
    case questCompleted(totalScore: Float, starsEarned: Int)
    case error(message: String)
}

/// Display-модель, которую Presenter публикует во View.
/// Содержит только готовый к рендеру текст и числа.
struct ARStoryQuestDisplay: Sendable, Equatable {
    var questTitle: String = ""
    var narration: String = ""
    var targetWord: String = ""
    var hint: String = ""
    var stepNumber: Int = 1
    var totalSteps: Int = 8
    var progressFraction: Double = 0
    var rewardEmoji: String = ""
    var isListening: Bool = false
    var lastScore: Float = 0
    var feedbackText: String = ""
    var isCompleted: Bool = false
    var starsEarned: Int = 0
    var totalScore: Float = 0
    var showFeedback: Bool = false
    var canAdvance: Bool = false
    var isLoading: Bool = true
    var errorMessage: String?
}
