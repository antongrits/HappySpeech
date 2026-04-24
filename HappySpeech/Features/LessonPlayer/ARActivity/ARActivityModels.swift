import Foundation

// MARK: - ARActivity VIP Models
//
// ARActivity — точка входа для AR-упражнений внутри сессии.
// Получает `SessionActivity` из SessionShell, определяет подходящий AR-режим
// по группе звуков и стадии коррекции, показывает preview-экран и после
// старта делегирует взаимодействие дочернему AR-view (ARMirrorView или
// ARStoryQuestView). По завершении подсчитывает звёзды и возвращает
// финальный score (0.0–1.0) родителю через `onComplete`.

enum ARActivityModels {

    // MARK: - LoadActivity

    /// Построение preview-данных по параметрам упражнения.
    enum LoadActivity {
        struct Request: Sendable {
            let contentUnitId: String
            let soundGroup: String      // "whistling" | "hissing" | "sonants" | "velar" | ""
            let targetSound: String     // "Р", "Л", "С", "Ш" и т.д.
            let stage: String           // "isolated" | "syllables" | "words" | ...
            let childName: String
        }

        struct Response: Sendable {
            let activityType: ARActivityType
            let description: String
            let iconSystemName: String
            let estimatedMinutes: Int
            let targetSound: String
        }

        struct ViewModel: Sendable {
            let title: String
            let description: String
            let iconSystemName: String
            let estimatedLabel: String
            let activityType: ARActivityType
            let previewReady: Bool
        }
    }

    // MARK: - StartActivity

    /// Пользователь нажал «Начать» — переходим в AR-режим.
    enum StartActivity {
        struct Request: Sendable { let activityType: ARActivityType }
        struct Response: Sendable { let activityType: ARActivityType }
        struct ViewModel: Sendable { let activityType: ARActivityType }
    }

    // MARK: - CompleteActivity

    /// AR-view вернул score; подсчитываем звёзды и готовим итоговый экран.
    enum CompleteActivity {
        struct Request: Sendable {
            let activityType: ARActivityType
            let score: Float         // 0.0 – 1.0
            let attempts: Int
        }

        struct Response: Sendable {
            let score: Float
            let starsEarned: Int
            let message: String
        }

        struct ViewModel: Sendable {
            let starsEarned: Int
            let scoreLabel: String
            let message: String
            let score: Float
        }
    }
}

// MARK: - ARActivityType

/// Какой AR-экран будет показан ребёнку после preview.
enum ARActivityType: String, Sendable, Equatable {
    /// Артикуляционное зеркало — ARMirrorView (лицо + blendshapes).
    case mirror
    /// Нарративный квест — ARStoryQuestView (история с записью голоса).
    case storyQuest
}

// MARK: - ARActivityPhase

/// Последовательность состояний UI.
enum ARActivityPhase: Sendable, Equatable {
    case loading        // preview ещё строится
    case preview        // карточка «Начать»
    case active         // открыт дочерний AR-view
    case completed      // показан итог со звёздами
}

// MARK: - ARActivityViewDisplay

/// Наблюдаемый store, который Presenter заполняет данными для SwiftUI.
@Observable
@MainActor
final class ARActivityViewDisplay {
    var title: String = ""
    var description: String = ""
    var iconSystemName: String = "arkit"
    var estimatedLabel: String = ""
    var activityType: ARActivityType = .storyQuest
    var phase: ARActivityPhase = .loading
    var starsEarned: Int = 0
    var scoreLabel: String = ""
    var completionMessage: String = ""
    var lastScore: Float = 0
}
