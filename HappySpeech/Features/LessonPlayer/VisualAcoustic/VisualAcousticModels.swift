import Foundation
import SwiftUI

// MARK: - VisualAcoustic VIP Models
//
// «Визуально-акустическая связь» — игра на ассоциацию «образ + звук».
// Ребёнку показывают иллюстрацию (emoji) и голосом зачитывают вопрос
// («Как звучит змея? Найди слово со звуком С»). Нужно из 4 вариантов
// выбрать то, в котором есть целевой звук. 6 раундов подряд на группу,
// итоговый экран со звёздами (≥0.9→3, ≥0.7→2, ≥0.5→1, иначе 0).
//
// Все модели согласованы с Clean Swift VIP: Request → Response → ViewModel.
// Бизнес-логика и каталог раундов — в `VisualAcousticInteractor`, формат
// строк и звёзды — в `VisualAcousticPresenter`. SwiftUI-слой читает
// `VisualAcousticDisplay` (@Observable) через `VisualAcousticDisplayLogic`.

enum VisualAcousticModels {

    // MARK: - LoadRound

    enum LoadRound {
        struct Request {
            let activity: SessionActivity
            let roundIndex: Int
        }
        struct Response {
            let round: VisualAcousticRound
            let roundIndex: Int
            let totalRounds: Int
        }
        struct ViewModel {
            let imageEmoji: String
            let imageLabel: String
            let question: String
            let questionWithSound: String
            let choices: [String]
            let roundIndex: Int
            let totalRounds: Int
            let progressFraction: Double
        }
    }

    // MARK: - PlayAudio

    enum PlayAudio {
        struct Request {}
        struct Response {
            let isPlaying: Bool
        }
        struct ViewModel {
            let isPlaying: Bool
        }
    }

    // MARK: - ChoiceWord

    enum ChoiceWord {
        struct Request {
            let choiceIndex: Int
        }
        struct Response {
            let choiceIndex: Int
            let correctIndex: Int
            let isCorrect: Bool
            let correctWord: String
        }
        struct ViewModel {
            let choiceResults: [ChoiceResult]
            let feedbackCorrect: Bool
            let feedbackText: String
        }
    }

    // MARK: - NextRound

    enum NextRound {
        struct Request {}
        struct Response {
            let hasNextRound: Bool
            let nextRoundIndex: Int
        }
        struct ViewModel {
            let hasNextRound: Bool
            let nextRoundIndex: Int
        }
    }

    // MARK: - Complete

    enum Complete {
        struct Request {}
        struct Response {
            let correctCount: Int
            let totalRounds: Int
            let score: Float
        }
        struct ViewModel {
            let scoreLabel: String
            let starsEarned: Int
            let completionMessage: String
            let finalScore: Float
        }
    }
}

// MARK: - Domain types

/// Один раунд игры: картинка + вопрос + 4 варианта.
struct VisualAcousticRound: Sendable, Equatable, Hashable {
    let id: UUID
    let imageEmoji: String           // "🐍"
    let imageLabel: String           // "Змея"
    let question: String             // "Как звучит змея?"
    let questionWithSound: String    // "Найди слово со звуком «С»"
    let choices: [String]            // 4 варианта
    let correctIndex: Int            // индекс правильного
    let soundGroup: String           // whistling / hissing / sonants / velar
    let ttsText: String              // полный текст для TTS (question + варианты)
}

/// Результат выбора одного варианта.
enum ChoiceResult: Sendable, Equatable {
    case none
    case correct
    case wrong(correctIndex: Int)
}

/// Фаза игры — управляет переключением экранов во View.
enum VisualAcousticPhase: Sendable, Equatable {
    case loading
    case presenting   // показ картинки + вопрос + кнопка «Слушать»
    case choosing     // TTS прозвучал, варианты активны
    case feedback     // результат, автопереход на следующий раунд
    case completed    // финал со звёздами
}

// MARK: - View display state

/// @Observable-хранилище, которое читает SwiftUI-`VisualAcousticView`.
/// Реализует `VisualAcousticDisplayLogic` в одноимённом файле.
@MainActor
@Observable
final class VisualAcousticDisplay {

    // Раунд
    var imageEmoji: String = ""
    var imageLabel: String = ""
    var question: String = ""
    var questionWithSound: String = ""
    var choices: [String] = []
    var choiceResults: [ChoiceResult] = []

    // Прогресс
    var roundIndex: Int = 0          // 0-based
    var totalRounds: Int = 6
    var progressFraction: Double = 0

    // Фаза
    var phase: VisualAcousticPhase = .loading
    var isPlaying: Bool = false      // TTS активен

    // Обратная связь
    var feedbackCorrect: Bool = false
    var feedbackText: String = ""

    // Финал
    var starsEarned: Int = 0
    var scoreLabel: String = ""
    var completionMessage: String = ""
    var lastScore: Float = 0
    var pendingFinalScore: Float?
}

// MARK: - Scoring

enum VisualAcousticScoring {
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
