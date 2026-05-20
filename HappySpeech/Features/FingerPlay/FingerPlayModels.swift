import Foundation

// MARK: - FingerPlayModels
//
// v31 Wave E Ф.2 — «Пальчики-говоруны» (methodology Ф6).
//
// Vision-based пальчиковая гимнастика. Реализует кинезиогимнастику
// (Архипова, Лопухина, Сиротюк): межполушарное взаимодействие через
// последовательность жестов. Камера + Vision Hand Pose определяет
// совпадение жеста ребёнка с целевым.
//
// Корпус: `Content/Seed/pack_fingerplay.json` — 16 упражнений × 3 стадии
// (показ → имитация → ритмическое повторение).

enum FingerPlayModels {

    // MARK: - Start

    enum Start {

        struct Request {
            let permissionGranted: Bool
        }

        struct Response {
            let exercise: FingerExercise
            let totalExercises: Int
        }

        struct ViewModel {
            let exerciseTitle: String
            let stageDescription: String
            let targetGestureSymbol: String
            let targetPoseRaw: String
            let totalExercises: Int
            let currentIndex: Int
            let stageIndex: Int  // 0,1,2 — показ/имитация/ритм
            let isPermissionDenied: Bool
            let accessibilityLabel: String
        }
    }

    // MARK: - HandPoseUpdate (поток из камеры)

    enum HandPoseUpdate {

        struct Response {
            let detectedPose: String     // HandPose.rawValue
            let matchesTarget: Bool
            let confidence: Float
        }

        struct ViewModel {
            let detectedPoseSymbol: String
            let matchesTarget: Bool
            let confidencePercent: Int
        }
    }

    // MARK: - Advance (переход к следующему упражнению / стадии)

    enum Advance {

        struct Response {
            let nextExercise: FingerExercise?
            let nextStage: Int
            let isSessionFinished: Bool
            let completedCount: Int
        }

        struct ViewModel {
            let nextStartVM: FingerPlayModels.Start.ViewModel?
            let isSessionFinished: Bool
            let completedCount: Int
            let summaryMessage: String?
        }
    }
}

// MARK: - FingerExercise

/// Пальчиковая или кинезио-упражнение из корпуса pack_fingerplay.json.
struct FingerExercise: Sendable, Identifiable, Equatable {
    let id: String
    let title: String                  // «Зайчик», «Колечко», «Кулак-ребро-ладонь»
    let rhymeText: String              // стих-договорка для синхронизации
    let stages: [FingerStage]
}

/// Одна стадия упражнения: показ → имитация → ритм.
struct FingerStage: Sendable, Equatable {
    /// Цель жеста — HandPose.rawValue.
    let targetPose: String
    /// SF Symbol для UI-подсказки.
    let symbol: String
    /// Описание для ребёнка («сложи кулачок»).
    let description: String
    /// Сколько раз нужно повторить (для финальной стадии).
    let repetitions: Int
}

/// Доступные жесты — подмножество HandPose, удобное для детей 5–8 лет.
enum FingerPlayGesture: String, Sendable, CaseIterable {
    case fist
    case openPalm
    case point
    case pinch
    case thumbsUp

    /// SF Symbol для иконки.
    var symbol: String {
        switch self {
        case .fist:      return "hand.raised.fingers.spread.fill"
        case .openPalm:  return "hand.raised.fill"
        case .point:     return "hand.point.up.left.fill"
        case .pinch:     return "hand.pinch.fill"
        case .thumbsUp:  return "hand.thumbsup.fill"
        }
    }

    /// Соответствующий HandPose.rawValue из HandPoseWorker.
    var handPoseRawValue: String {
        switch self {
        case .fist:      return "fist"
        case .openPalm:  return "open_palm"
        case .point:     return "point"
        case .pinch:     return "pinch"
        case .thumbsUp:  return "thumbs_up"
        }
    }
}
