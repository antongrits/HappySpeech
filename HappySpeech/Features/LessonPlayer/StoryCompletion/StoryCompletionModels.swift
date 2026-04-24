import Foundation

// MARK: - StoryCompletion VIP Models
//
// «Заверши историю» — 5 сцен подряд. В каждой сцене маскот-логопед зачитывает
// короткую историю с пропуском (`___`), ребёнок выбирает правильное слово из
// трёх вариантов. Правильное всегда содержит целевой звук. После 5 сцен —
// итоговый экран со звёздами (≥0.9→3, ≥0.7→2, ≥0.5→1, иначе 0).
//
// Все модели согласованы с Clean Swift VIP: Request → Response → ViewModel.
// Бизнес-логика живёт в `StoryCompletionInteractor`, форматирование строк и
// звёзды — в `StoryCompletionPresenter`. View читает `StoryCompletionDisplay`,
// @Observable-хранилище, которое реализует `StoryCompletionDisplayLogic`.

enum StoryCompletionModels {

    // MARK: - LoadStory

    enum LoadStory {
        struct Request {
            let activity: SessionActivity
            let sceneIndex: Int
        }
        struct Response {
            let scene: StoryScene
            let sceneIndex: Int
            let totalScenes: Int
        }
        struct ViewModel {
            let storyText: String        // «Маша пошла в лес и нашла большую ___.»
            let displayText: String      // «…большую _______.» (до выбора)
            let choices: [String]
            let emoji: String
            let sceneIndex: Int
            let totalScenes: Int
            let progressFraction: Double
            let isReading: Bool          // true — TTS стартует; используем для hint
        }
    }

    // MARK: - ChooseWord

    enum ChooseWord {
        struct Request {
            let choiceIndex: Int
        }
        struct Response {
            let choiceIndex: Int
            let correctIndex: Int
            let isCorrect: Bool
            let chosenWord: String
            let correctWord: String
            let filledStoryText: String  // история с подставленным ПРАВИЛЬНЫМ словом
        }
        struct ViewModel {
            let choiceStates: [ChoiceState]
            let filledStoryText: String
            let feedbackCorrect: Bool
            let feedbackMessage: String
        }
    }

    // MARK: - NextScene

    enum NextScene {
        struct Request {}
        struct Response {
            let hasNextScene: Bool
            let nextSceneIndex: Int
        }
        struct ViewModel {
            let hasNextScene: Bool
            let nextSceneIndex: Int
        }
    }

    // MARK: - Complete

    enum Complete {
        struct Request {}
        struct Response {
            let correctCount: Int
            let totalScenes: Int
            let score: Float              // 0…1
        }
        struct ViewModel {
            let scoreLabel: String        // «Результат: 80%»
            let starsEarned: Int          // 0…3
            let completionMessage: String
            let finalScore: Float
        }
    }
}

// MARK: - Domain types

/// Одна сцена истории.
struct StoryScene: Sendable, Equatable, Hashable {
    let id: UUID
    let storyText: String        // полный текст с "___" на месте пропуска
    let choices: [String]        // 3 варианта
    let correctIndex: Int        // 0…2
    let soundGroup: String       // whistling / hissing / sonants / velar
    let emoji: String            // иллюстрация сцены
}

/// Визуальное состояние варианта ответа.
enum ChoiceState: Sendable, Equatable {
    case idle
    case correct
    case wrong
    case revealed   // показываем правильный после ошибки
}

/// Фаза игры — управляет переключением экранов во View.
enum StoryPhase: Sendable, Equatable {
    case loading
    case reading     // TTS зачитывает историю, выбор недоступен
    case choosing    // кнопки выбора активны
    case feedback    // подсветка правильного/неправильного, overlay «Дальше»
    case completed   // финальный экран со звёздами
}

/// Плейсхолдер, которым заменяется `___` до выбора варианта.
enum StoryPlaceholder {
    /// 7 символов подчёркивания — визуальный blank длиннее слова.
    static let blank: String = "_______"
    /// Маркер в исходном тексте — ровно три подчёркивания.
    static let marker: String = "___"
}

// MARK: - View display state

/// @Observable-хранилище, которое читает SwiftUI-`StoryCompletionView`.
/// Реализует `StoryCompletionDisplayLogic` в одноимённом файле.
@MainActor
@Observable
final class StoryCompletionDisplay {

    // Сцена
    var storyText: String = ""           // полный текст текущей сцены (с "___")
    var displayText: String = ""         // текст для показа — до выбора "_______",
                                         // после — с подставленным словом
    var choices: [String] = []
    var choiceStates: [ChoiceState] = [.idle, .idle, .idle]
    var emoji: String = ""

    // Прогресс
    var sceneIndex: Int = 0              // 0-based
    var totalScenes: Int = 5
    var progressFraction: Double = 0

    // Фаза
    var phase: StoryPhase = .loading
    var isReading: Bool = false          // TTS активен (для спикер-иконки)

    // Обратная связь
    var feedbackCorrect: Bool = false
    var feedbackMessage: String = ""

    // Финал
    var starsEarned: Int = 0
    var scoreLabel: String = ""
    var completionMessage: String = ""
    var lastScore: Float = 0
    var pendingFinalScore: Float?
}

// MARK: - Scoring

enum StoryCompletionScoring {
    /// Жёсткая шкала: ≥0.9→3, ≥0.7→2, ≥0.5→1, иначе 0.
    static func stars(for score: Float) -> Int {
        switch score {
        case 0.9...:    return 3
        case 0.7..<0.9: return 2
        case 0.5..<0.7: return 1
        default:        return 0
        }
    }
}
