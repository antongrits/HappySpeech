import Foundation

// MARK: - SoundHunter VIP Models
//
// «Охота на звук» — ребёнок видит сцену из 9 предметов (сетка 3×3) и должен
// нажать на те, в названии которых есть целевой звук. За правильное нажатие
// предмет «загорается» зелёным с галочкой, за ошибочное — трясётся красным.
// Игра состоит из 3 сцен; после каждой — короткая заставка «Отлично!», после
// третьей — итог со звёздами и финальным score (правильных / всех целевых).

enum SoundHunterModels {

    // MARK: - LoadScene

    /// Загрузка сцены: выбор предметов по группе звуков и индексу сцены.
    enum LoadScene {
        struct Request: Sendable {
            let sceneIndex: Int
        }

        struct Response: Sendable {
            let items: [HuntItem]
            let targetSound: String
            let targetSoundGroup: String
            let sceneIndex: Int
            let totalScenes: Int
            let totalCorrectNeeded: Int
        }

        struct ViewModel: Sendable {
            let items: [HuntItem]
            let targetSound: String
            let targetSoundGroup: String
            let sceneIndex: Int
            let totalScenes: Int
            let totalCorrectNeeded: Int
            let progressFraction: Double
            let hintText: String
        }
    }

    // MARK: - TapItem

    /// Нажатие на предмет в сетке.
    enum TapItem {
        struct Request: Sendable {
            let itemId: UUID
        }

        struct Response: Sendable {
            let itemId: UUID
            let newState: TapState
            let correctCount: Int
            let totalCorrectNeeded: Int
            let isSceneComplete: Bool
        }

        struct ViewModel: Sendable {
            let itemId: UUID
            let newState: TapState
            let correctCount: Int
            let totalCorrectNeeded: Int
            let progressFraction: Double
            let shakeItemId: UUID?
            let isSceneComplete: Bool
        }
    }

    // MARK: - CompleteScene

    /// Все целевые предметы в сцене найдены. Готовится автопереход.
    enum CompleteScene {
        struct Request: Sendable {}

        struct Response: Sendable {
            let totalScore: Float
            let starsEarned: Int
            let isFinalScene: Bool
        }

        struct ViewModel: Sendable {
            let totalScore: Float
            let starsEarned: Int
            let scoreLabel: String
            let completionMessage: String
            let isFinalScene: Bool
        }
    }

    // MARK: - NextScene

    /// Переход к следующей сцене.
    enum NextScene {
        struct Request: Sendable {}

        struct Response: Sendable {
            let nextSceneIndex: Int
            let items: [HuntItem]
            let targetSound: String
            let totalCorrectNeeded: Int
        }

        struct ViewModel: Sendable {
            let nextSceneIndex: Int
            let items: [HuntItem]
            let targetSound: String
            let totalCorrectNeeded: Int
            let progressFraction: Double
            let hintText: String
        }
    }
}

// MARK: - HuntItem

/// Предмет на сцене охоты. Хранит русское слово, имя SF Symbol, флаг «содержит ли
/// целевой звук» и текущее состояние нажатия.
struct HuntItem: Identifiable, Sendable, Equatable {
    let id: UUID
    let word: String
    let icon: String
    let hasTargetSound: Bool
    var tapState: TapState

    init(
        id: UUID = UUID(),
        word: String,
        icon: String,
        hasTargetSound: Bool,
        tapState: TapState = .idle
    ) {
        self.id = id
        self.word = word
        self.icon = icon
        self.hasTargetSound = hasTargetSound
        self.tapState = tapState
    }
}

// MARK: - TapState

/// Визуальное состояние карточки-предмета.
enum TapState: String, Sendable, Equatable {
    case idle       // нейтральное
    case correct    // зелёное, с галочкой
    case wrong      // красное, с тряской
    case revealed   // золотое: показываем правильный ответ после раунда
}

// MARK: - SoundHunterPhase

/// Фазы экрана.
enum SoundHunterPhase: Sendable, Equatable {
    case loading
    case hunting
    case sceneComplete
    case completed
}

// MARK: - SoundHunterDisplay

/// Наблюдаемый store — заполняется Presenter'ом, читается View.
@Observable
@MainActor
final class SoundHunterDisplay {
    var items: [HuntItem] = []
    var targetSound: String = ""
    var targetSoundGroup: String = ""
    var sceneIndex: Int = 0
    var totalScenes: Int = 3
    var correctCount: Int = 0
    var totalCorrectNeeded: Int = 0
    var phase: SoundHunterPhase = .loading
    var progressFraction: Double = 0
    var starsEarned: Int = 0
    var scoreLabel: String = ""
    var completionMessage: String = ""
    var lastScore: Float = 0
    var hintText: String = ""
    var shakeItemId: UUID?
}
