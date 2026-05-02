import Foundation

// MARK: - ObjectHuntModels
//
// VIP-модели для игры «Охота за предметом» (Object Hunt).
//
// Игровой поток:
//   1. LoadScene   → загружает сцену (8–12 предметов, целевой звук, 60-сек таймер)
//   2. TapObject   → ребёнок нажал предмет → correct / wrong / already-tapped
//   3. UseHint     → запрос подсказки (не более 2 на раунд)
//   4. TimerTick   → каждую секунду из View
//   5. CompleteScene → все целевые найдены (или время вышло)
//   6. CompleteGame  → все 5 раундов завершены
//
// Всего раундов: 5 (по одному на каждую scene из каталога).

// MARK: - SceneItem

/// Один предмет в сцене.
struct SceneItem: Identifiable, Sendable, Equatable {
    let id: UUID
    let word: String                     // русское слово
    let icon: String                     // SF Symbol
    let hasTargetSound: Bool             // правильный / отвлекающий
    var tapState: SceneItemTapState      // idle / correct / wrong / hint
    var isHintActive: Bool               // подсказка сейчас мигает

    init(
        word: String,
        icon: String,
        hasTargetSound: Bool
    ) {
        self.id = UUID()
        self.word = word
        self.icon = icon
        self.hasTargetSound = hasTargetSound
        self.tapState = .idle
        self.isHintActive = false
    }
}

// MARK: - SceneItemTapState

enum SceneItemTapState: Equatable, Sendable {
    case idle
    case correct
    case wrong    // временное состояние — через 0.5 сек сбрасывается в idle
    case hinted   // получил подсказку — лёгкая подсветка
}

// MARK: - SceneDescriptor

struct SceneDescriptor: Sendable {
    let name: String            // "кухня", "лес", "океан" …
    let systemBackground: String  // SF Symbol для декора фона
}

// MARK: - ObjectHuntModels

enum ObjectHuntModels {

    // MARK: - LoadScene

    enum LoadScene {
        struct Request {
            let soundGroup: String      // "whistling" | "hissing" | "sonants" | "velar"
            let targetSound: String     // конкретный звук, пример: "Ш"
            let sceneIndex: Int         // 0…4
        }
        struct Response {
            let items: [SceneItem]
            let targetSound: String
            let scene: SceneDescriptor
            let sceneIndex: Int
            let totalScenes: Int
            let targetCount: Int        // сколько правильных в этой сцене
            let timeLimitSec: Int       // 60
        }
        struct ViewModel {
            let items: [SceneItem]
            let targetSoundLabel: String
            let sceneName: String
            let sceneBackground: String
            let roundBadge: String      // "Раунд 1 из 5"
            let promptText: String      // "Найди что начинается на Ш!"
            let targetCount: Int
            let timeLimitSec: Int
        }
    }

    // MARK: - TapObject

    enum TapObject {
        struct Request {
            let itemId: UUID
        }
        struct Response {
            let itemId: UUID
            let newState: SceneItemTapState
            let isCorrect: Bool
            let word: String            // для голосового объявления
            let correctCount: Int
            let targetCount: Int
            let streakCount: Int
            let score: Int
            let isSceneComplete: Bool
        }
        struct ViewModel {
            let itemId: UUID
            let newState: SceneItemTapState
            let isCorrect: Bool
            let word: String
            let correctCount: Int
            let targetCount: Int
            let streakCount: Int
            let scoreLabel: String      // "+5", "+10 серия!"
            let isSceneComplete: Bool
        }
    }

    // MARK: - UseHint

    enum UseHint {
        struct Request {}
        struct Response {
            let hintedItemId: UUID?     // предмет, получивший подсветку
            let hintsRemaining: Int
            let hintLevel: Int          // 1 = shake, 2 = glow
        }
        struct ViewModel {
            let hintedItemId: UUID?
            let hintsRemaining: Int
            let hintLevel: Int
            let isHintAvailable: Bool
        }
    }

    // MARK: - TimerTick

    enum TimerTick {
        struct Request {}
        struct Response {
            let secondsRemaining: Int
            let isExpired: Bool
        }
        struct ViewModel {
            let timerLabel: String      // "0:45"
            let isExpired: Bool
            let isWarning: Bool         // < 15 сек — красный цвет
        }
    }

    // MARK: - CompleteScene

    enum CompleteScene {
        struct Response {
            let sceneIndex: Int
            let foundCount: Int
            let targetCount: Int
            let timeUsedSec: Int
            let streakBonus: Int
            let sceneScore: Int
            let isLastScene: Bool
        }
        struct ViewModel {
            let sceneIndex: Int
            let summaryText: String     // "Нашёл 4 из 4!"
            let timeText: String        // "за 32 секунды"
            let streakBonusText: String // "" или "+15 за серию!"
            let isLastScene: Bool
        }
    }

    // MARK: - CompleteGame

    enum CompleteGame {
        struct Response {
            let totalScore: Int
            let maxScore: Int
            let starsEarned: Int
            let totalFound: Int
            let totalTargets: Int
            let accuracy: Float
        }
        struct ViewModel {
            let starsEarned: Int
            let scoreLabel: String      // "Счёт: 235"
            let accuracyLabel: String   // "Точность: 87%"
            let summaryText: String
        }
    }

    // MARK: - GamePhase

    enum GamePhase: Equatable, Sendable {
        case loading
        case playing
        case sceneComplete
        case gameComplete
    }
}
