import Foundation

// MARK: - ArticulationImitation VIP Models
//
// "Повтори артикуляцию" — серия из 5 артикуляционных упражнений
// (улыбка, хоботок, лопатка, иголочка, чашечка, маляр, лошадка,
// вкусное варенье, часики, качели). Ребёнок видит инструкцию и
// удерживает позу `holdSeconds` секунд. AR не используется —
// только иллюстрация-эмодзи и текстовая подсказка.
//
// Сценарий:
//   loading → exercisePreview(i) → holding(i) → feedback(i) →
//   → (next i) exercisePreview(i+1) | completed
//
// Самооценка: на этапе `holding` интерактор запускает таймер
// 0.1с-тиками; при достижении 100% автоматически переходит в
// feedback с earnedStar = true. Если ребёнок отпустил кнопку
// (ручное завершение) до таймера — feedback с earnedStar = false.

// MARK: - ArticulationExercise

struct ArticulationExercise: Sendable, Identifiable, Equatable {
    let id: String
    /// Короткое название (заголовок карточки).
    let name: String
    /// Инструкция для ребёнка.
    let instruction: String
    /// Целевой звук (для адаптивной фильтрации).
    let targetSound: String
    /// Сколько секунд удерживать позу.
    let holdSeconds: Int
    /// Эмодзи-иллюстрация.
    let emoji: String
    /// SF Symbol fallback (используется, если эмодзи нельзя отрендерить).
    let systemImageName: String
}

extension ArticulationExercise {

    // Полный каталог базовых артикуляционных упражнений.
    // 10 классических упражнений русской логопедии (лопатка, иголочка,
    // чашечка, маляр, лошадка, вкусное варенье, часики, качели, улыбка,
    // хоботок). При добавлении нового — обновить тесты.
    static let catalog: [ArticulationExercise] = [
        ArticulationExercise(
            id: "smile",
            name: String(localized: "articulation.exercise.smile.name"),
            instruction: String(localized: "articulation.exercise.smile.instruction"),
            targetSound: "С",
            holdSeconds: 3,
            emoji: "😁",
            systemImageName: "face.smiling"
        ),
        ArticulationExercise(
            id: "tube",
            name: String(localized: "articulation.exercise.tube.name"),
            instruction: String(localized: "articulation.exercise.tube.instruction"),
            targetSound: "Ш",
            holdSeconds: 3,
            emoji: "😗",
            systemImageName: "circle.fill"
        ),
        ArticulationExercise(
            id: "spatula",
            name: String(localized: "articulation.exercise.spatula.name"),
            instruction: String(localized: "articulation.exercise.spatula.instruction"),
            targetSound: "Л",
            holdSeconds: 3,
            emoji: "👅",
            systemImageName: "rectangle.fill"
        ),
        ArticulationExercise(
            id: "needle",
            name: String(localized: "articulation.exercise.needle.name"),
            instruction: String(localized: "articulation.exercise.needle.instruction"),
            targetSound: "Р",
            holdSeconds: 3,
            emoji: "👄",
            systemImageName: "arrow.right"
        ),
        ArticulationExercise(
            id: "cup",
            name: String(localized: "articulation.exercise.cup.name"),
            instruction: String(localized: "articulation.exercise.cup.instruction"),
            targetSound: "Ш",
            holdSeconds: 3,
            emoji: "☕",
            systemImageName: "cup.and.saucer.fill"
        ),
        ArticulationExercise(
            id: "painter",
            name: String(localized: "articulation.exercise.painter.name"),
            instruction: String(localized: "articulation.exercise.painter.instruction"),
            targetSound: "Р",
            holdSeconds: 3,
            emoji: "🖌️",
            systemImageName: "paintbrush.fill"
        ),
        ArticulationExercise(
            id: "horse",
            name: String(localized: "articulation.exercise.horse.name"),
            instruction: String(localized: "articulation.exercise.horse.instruction"),
            targetSound: "Р",
            holdSeconds: 3,
            emoji: "🐴",
            systemImageName: "waveform"
        ),
        ArticulationExercise(
            id: "jam",
            name: String(localized: "articulation.exercise.jam.name"),
            instruction: String(localized: "articulation.exercise.jam.instruction"),
            targetSound: "Л",
            holdSeconds: 3,
            emoji: "😋",
            systemImageName: "face.smiling.fill"
        ),
        ArticulationExercise(
            id: "watch",
            name: String(localized: "articulation.exercise.watch.name"),
            instruction: String(localized: "articulation.exercise.watch.instruction"),
            targetSound: "З",
            holdSeconds: 3,
            emoji: "⏰",
            systemImageName: "clock.fill"
        ),
        ArticulationExercise(
            id: "swing",
            name: String(localized: "articulation.exercise.swing.name"),
            instruction: String(localized: "articulation.exercise.swing.instruction"),
            targetSound: "С",
            holdSeconds: 3,
            emoji: "🎡",
            systemImageName: "arrow.up.arrow.down"
        )
    ]

    /// Детерминистический набор упражнений для сессии.
    /// Фильтруем каталог по группе звуков, берём первые `count`. Если
    /// группа пустая (например, неизвестный таргет) — возвращаем первые
    /// `count` из общего каталога.
    static func exercises(for soundGroup: String, count: Int = 5) -> [ArticulationExercise] {
        let pool = catalog.filter { exercise in
            switch soundGroup {
            case SoundFamily.whistling.rawValue:
                return ["С", "З", "Ц"].contains(exercise.targetSound)
            case SoundFamily.hissing.rawValue:
                return ["Ш", "Ж", "Ч", "Щ"].contains(exercise.targetSound)
            case SoundFamily.sonorant.rawValue:
                return ["Р", "Л"].contains(exercise.targetSound)
            case SoundFamily.velar.rawValue:
                return ["К", "Г", "Х"].contains(exercise.targetSound)
            default:
                return true
            }
        }
        let working = pool.isEmpty ? catalog : pool
        // Стабильный порядок: берём начало отсортированного по id списка
        // (чтобы превью и тесты были детерминистическими).
        let sorted = working.sorted { $0.id < $1.id }
        return Array(sorted.prefix(count))
    }
}

// MARK: - Phase

enum ArticulationPhase: Sendable, Equatable {
    case loading
    case exercisePreview
    case holding
    case feedback
    case completed
}

// MARK: - VIP envelopes

enum ArticulationImitationModels {

    // MARK: LoadSession
    enum LoadSession {
        struct Request: Sendable {
            let soundGroup: String
            let childName: String
        }
        struct Response: Sendable {
            let exercises: [ArticulationExercise]
            let childName: String
        }
        struct ViewModel: Sendable {
            let exercises: [ArticulationExercise]
            let greeting: String
        }
    }

    // MARK: StartExercise
    enum StartExercise {
        struct Request: Sendable {
            let exerciseIndex: Int
        }
        struct Response: Sendable {
            let exercise: ArticulationExercise
            let exerciseNumber: Int
            let total: Int
        }
        struct ViewModel: Sendable {
            let exercise: ArticulationExercise
            let progressLabel: String
            let canStart: Bool
        }
    }

    // MARK: HoldProgress
    enum HoldProgress {
        struct Request: Sendable {
            let elapsedSeconds: Double
        }
        struct Response: Sendable {
            let fraction: Double
            let completed: Bool
            let remainingSeconds: Int
        }
        struct ViewModel: Sendable {
            let fraction: Double
            let timerLabel: String
            let completed: Bool
        }
    }

    // MARK: CompleteExercise
    enum CompleteExercise {
        struct Request: Sendable {
            let exerciseId: String
            let held: Bool
        }
        struct Response: Sendable {
            let earnedStar: Bool
            let nextIndex: Int?
            let allDone: Bool
        }
        struct ViewModel: Sendable {
            let earnedStar: Bool
            let feedbackText: String
            let allDone: Bool
        }
    }

    // MARK: SessionComplete
    enum SessionComplete {
        struct Request: Sendable {}
        struct Response: Sendable {
            let starsTotal: Int
            let outOf: Int
        }
        struct ViewModel: Sendable {
            let starsTotal: Int
            let outOf: Int
            let scoreLabel: String
            let message: String
            /// Нормализованный скор 0…1 для onComplete колбэка SessionShell.
            let normalizedScore: Float
        }
    }
}

// MARK: - Display store

/// `@Observable` store, к которому подписан View. Роль `DisplayLogic` —
/// Presenter пишет в него, SwiftUI перерисовывает поля.
@MainActor
@Observable
final class ArticulationImitationDisplay {
    var greeting: String = ""
    var currentExercise: ArticulationExercise?
    var exerciseNumber: Int = 0
    var totalExercises: Int = 0
    var progressLabel: String = ""
    var holdFraction: Double = 0
    var timerLabel: String = ""
    var earnedStar: Bool = false
    var feedbackText: String = ""
    var allDone: Bool = false
    var starsTotal: Int = 0
    var outOf: Int = 5
    var scoreLabel: String = ""
    var completionMessage: String = ""
    var phase: ArticulationPhase = .loading
    /// Финальный скор, пробрасываемый наверх через SessionShell.onComplete.
    /// View наблюдает за этим полем в `.onChange` и вызывает колбэк.
    var pendingFinalScore: Float?
}
