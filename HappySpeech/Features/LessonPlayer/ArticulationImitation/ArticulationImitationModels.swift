import Foundation

// MARK: - ArticulationImitation VIP Models
//
// "Зеркало": ребёнок имитирует 12 артикуляционных поз Ляли.
// AR Face Tracking (TrueDepth) анализирует blendshapes в реальном времени.
// На устройствах без TrueDepth — fallback 2D-иллюстрация + подтверждение родителя.
//
// Сценарий (одна поза):
//   posePreview → mirroring (AR/2D) → poseFeedback → [следующая] | completed
//
// Структура раунда:
//   12 поз × до 3 попыток каждая. Порог успеха ≥75 (score 0–100).

// MARK: - ArticulationPose

/// Одна артикуляционная поза из набора 12.
struct ArticulationPose: Sendable, Identifiable, Equatable {
    let id: String
    /// Короткое название (заголовок карточки).
    let name: String
    /// Инструкция для ребёнка.
    let instruction: String
    /// Голосовая подсказка Ляли.
    let voicePrompt: String
    /// Эмодзи-иллюстрация.
    let emoji: String
    /// SF Symbol fallback.
    let systemImageName: String
    /// Целевой звук (для адаптивной фильтрации).
    let targetSound: String
    /// Пороговые значения blendshapes для успешного матчинга.
    let blendshapeTargets: [BlendshapeTarget]
    /// Подсказка при провале первой попытки.
    let hint1: String
    /// Подсказка при провале второй попытки.
    let hint2: String
}

// MARK: - BlendshapeTarget

/// Требование к одному blendshape-каналу ARKit для данной позы.
struct BlendshapeTarget: Sendable, Equatable {
    /// Идентификатор канала (например "jawOpen").
    let channel: String
    /// Минимальное значение для прохождения (0…1).
    let minValue: Float
    /// Максимальное значение (1 = без ограничения сверху).
    let maxValue: Float
    /// Вес канала при агрегации итоговой оценки.
    let weight: Float
}

// MARK: - PoseCatalog

extension ArticulationPose {

    // MARK: Полный каталог 12 поз русской логопедии.
    // А, О, У, И, Э, Ы, М, П/Б, С, Ш, Р + нейтральная «Закрыт»
    static let catalog: [ArticulationPose] = [
        ArticulationPose(
            id: "pose_a",
            name: String(localized: "artposeA.name"),
            instruction: String(localized: "artposeA.instruction"),
            voicePrompt: String(localized: "artposeA.prompt"),
            emoji: "mouth.fill",
            systemImageName: "mouth",
            targetSound: "А",
            blendshapeTargets: [
                BlendshapeTarget(channel: "jawOpen", minValue: 0.55, maxValue: 1.0, weight: 0.7),
                BlendshapeTarget(channel: "mouthClose", minValue: 0.0, maxValue: 0.2, weight: 0.3)
            ],
            hint1: String(localized: "artposeA.hint1"),
            hint2: String(localized: "artposeA.hint2")
        ),
        ArticulationPose(
            id: "pose_o",
            name: String(localized: "artposeO.name"),
            instruction: String(localized: "artposeO.instruction"),
            voicePrompt: String(localized: "artposeO.prompt"),
            emoji: "mouth.fill",
            systemImageName: "circle",
            targetSound: "О",
            blendshapeTargets: [
                BlendshapeTarget(channel: "mouthFunnel", minValue: 0.4, maxValue: 1.0, weight: 0.5),
                BlendshapeTarget(channel: "jawOpen", minValue: 0.25, maxValue: 0.6, weight: 0.3),
                BlendshapeTarget(channel: "mouthPucker", minValue: 0.2, maxValue: 1.0, weight: 0.2)
            ],
            hint1: String(localized: "artposeO.hint1"),
            hint2: String(localized: "artposeO.hint2")
        ),
        ArticulationPose(
            id: "pose_u",
            name: String(localized: "artposeU.name"),
            instruction: String(localized: "artposeU.instruction"),
            voicePrompt: String(localized: "artposeU.prompt"),
            emoji: "mouth.fill",
            systemImageName: "circle.fill",
            targetSound: "У",
            blendshapeTargets: [
                BlendshapeTarget(channel: "mouthPucker", minValue: 0.5, maxValue: 1.0, weight: 0.6),
                BlendshapeTarget(channel: "mouthFunnel", minValue: 0.3, maxValue: 1.0, weight: 0.4)
            ],
            hint1: String(localized: "artposeU.hint1"),
            hint2: String(localized: "artposeU.hint2")
        ),
        ArticulationPose(
            id: "pose_i",
            name: String(localized: "artposeI.name"),
            instruction: String(localized: "artposeI.instruction"),
            voicePrompt: String(localized: "artposeI.prompt"),
            emoji: "mouth.fill",
            systemImageName: "face.smiling",
            targetSound: "И",
            blendshapeTargets: [
                BlendshapeTarget(channel: "mouthSmileLeft", minValue: 0.45, maxValue: 1.0, weight: 0.4),
                BlendshapeTarget(channel: "mouthSmileRight", minValue: 0.45, maxValue: 1.0, weight: 0.4),
                BlendshapeTarget(channel: "mouthStretchLeft", minValue: 0.2, maxValue: 1.0, weight: 0.1),
                BlendshapeTarget(channel: "mouthStretchRight", minValue: 0.2, maxValue: 1.0, weight: 0.1)
            ],
            hint1: String(localized: "artposeI.hint1"),
            hint2: String(localized: "artposeI.hint2")
        ),
        ArticulationPose(
            id: "pose_e",
            name: String(localized: "artposeE.name"),
            instruction: String(localized: "artposeE.instruction"),
            voicePrompt: String(localized: "artposeE.prompt"),
            emoji: "mouth.fill",
            systemImageName: "minus",
            targetSound: "Э",
            blendshapeTargets: [
                BlendshapeTarget(channel: "jawOpen", minValue: 0.2, maxValue: 0.5, weight: 0.5),
                BlendshapeTarget(channel: "mouthSmileLeft", minValue: 0.1, maxValue: 0.4, weight: 0.25),
                BlendshapeTarget(channel: "mouthSmileRight", minValue: 0.1, maxValue: 0.4, weight: 0.25)
            ],
            hint1: String(localized: "artposeE.hint1"),
            hint2: String(localized: "artposeE.hint2")
        ),
        ArticulationPose(
            id: "pose_y",
            name: String(localized: "artposeY.name"),
            instruction: String(localized: "artposeY.instruction"),
            voicePrompt: String(localized: "artposeY.prompt"),
            emoji: "mouth.fill",
            systemImageName: "rectangle",
            targetSound: "Ы",
            blendshapeTargets: [
                BlendshapeTarget(channel: "jawOpen", minValue: 0.15, maxValue: 0.45, weight: 0.4),
                BlendshapeTarget(channel: "mouthStretchLeft", minValue: 0.3, maxValue: 1.0, weight: 0.3),
                BlendshapeTarget(channel: "mouthStretchRight", minValue: 0.3, maxValue: 1.0, weight: 0.3)
            ],
            hint1: String(localized: "artposeY.hint1"),
            hint2: String(localized: "artposeY.hint2")
        ),
        ArticulationPose(
            id: "pose_m",
            name: String(localized: "artposeM.name"),
            instruction: String(localized: "artposeM.instruction"),
            voicePrompt: String(localized: "artposeM.prompt"),
            emoji: "mouth.fill",
            systemImageName: "mouth.fill",
            targetSound: "М",
            blendshapeTargets: [
                BlendshapeTarget(channel: "mouthClose", minValue: 0.6, maxValue: 1.0, weight: 0.7),
                BlendshapeTarget(channel: "jawOpen", minValue: 0.0, maxValue: 0.15, weight: 0.3)
            ],
            hint1: String(localized: "artposeM.hint1"),
            hint2: String(localized: "artposeM.hint2")
        ),
        ArticulationPose(
            id: "pose_p",
            name: String(localized: "artposeP.name"),
            instruction: String(localized: "artposeP.instruction"),
            voicePrompt: String(localized: "artposeP.prompt"),
            emoji: "mouth.fill",
            systemImageName: "mouth",
            targetSound: "П",
            blendshapeTargets: [
                BlendshapeTarget(channel: "mouthClose", minValue: 0.5, maxValue: 1.0, weight: 0.5),
                BlendshapeTarget(channel: "mouthRollLower", minValue: 0.2, maxValue: 1.0, weight: 0.3),
                BlendshapeTarget(channel: "mouthRollUpper", minValue: 0.2, maxValue: 1.0, weight: 0.2)
            ],
            hint1: String(localized: "artposeP.hint1"),
            hint2: String(localized: "artposeP.hint2")
        ),
        ArticulationPose(
            id: "pose_s",
            name: String(localized: "artposeS.name"),
            instruction: String(localized: "artposeS.instruction"),
            voicePrompt: String(localized: "artposeS.prompt"),
            emoji: "mouth.fill",
            systemImageName: "line.diagonal",
            targetSound: "С",
            blendshapeTargets: [
                BlendshapeTarget(channel: "tongueOut", minValue: 0.25, maxValue: 0.6, weight: 0.5),
                BlendshapeTarget(channel: "jawOpen", minValue: 0.15, maxValue: 0.4, weight: 0.3),
                BlendshapeTarget(channel: "mouthSmileLeft", minValue: 0.2, maxValue: 1.0, weight: 0.1),
                BlendshapeTarget(channel: "mouthSmileRight", minValue: 0.2, maxValue: 1.0, weight: 0.1)
            ],
            hint1: String(localized: "artposeS.hint1"),
            hint2: String(localized: "artposeS.hint2")
        ),
        ArticulationPose(
            id: "pose_sh",
            name: String(localized: "artposeSh.name"),
            instruction: String(localized: "artposeSh.instruction"),
            voicePrompt: String(localized: "artposeSh.prompt"),
            emoji: "🫦",
            systemImageName: "waveform.path",
            targetSound: "Ш",
            blendshapeTargets: [
                BlendshapeTarget(channel: "mouthFunnel", minValue: 0.35, maxValue: 1.0, weight: 0.5),
                BlendshapeTarget(channel: "mouthPucker", minValue: 0.15, maxValue: 0.6, weight: 0.3),
                BlendshapeTarget(channel: "jawOpen", minValue: 0.1, maxValue: 0.35, weight: 0.2)
            ],
            hint1: String(localized: "artposeSh.hint1"),
            hint2: String(localized: "artposeSh.hint2")
        ),
        ArticulationPose(
            id: "pose_r",
            name: String(localized: "artposeR.name"),
            instruction: String(localized: "artposeR.instruction"),
            voicePrompt: String(localized: "artposeR.prompt"),
            emoji: "mouth.fill",
            systemImageName: "arrow.up",
            targetSound: "Р",
            blendshapeTargets: [
                BlendshapeTarget(channel: "tongueOut", minValue: 0.15, maxValue: 0.5, weight: 0.4),
                BlendshapeTarget(channel: "jawOpen", minValue: 0.3, maxValue: 0.65, weight: 0.35),
                BlendshapeTarget(channel: "mouthUpperUpLeft", minValue: 0.1, maxValue: 1.0, weight: 0.125),
                BlendshapeTarget(channel: "mouthUpperUpRight", minValue: 0.1, maxValue: 1.0, weight: 0.125)
            ],
            hint1: String(localized: "artposeR.hint1"),
            hint2: String(localized: "artposeR.hint2")
        ),
        ArticulationPose(
            id: "pose_l",
            name: String(localized: "artposeL.name"),
            instruction: String(localized: "artposeL.instruction"),
            voicePrompt: String(localized: "artposeL.prompt"),
            emoji: "mouth.fill",
            systemImageName: "arrow.left.and.right",
            targetSound: "Л",
            blendshapeTargets: [
                BlendshapeTarget(channel: "tongueOut", minValue: 0.4, maxValue: 1.0, weight: 0.6),
                BlendshapeTarget(channel: "jawOpen", minValue: 0.2, maxValue: 0.55, weight: 0.4)
            ],
            hint1: String(localized: "artposeL.hint1"),
            hint2: String(localized: "artposeL.hint2")
        )
    ]

    /// Детерминированный набор поз для сессии по группе звуков.
    static func poses(for soundGroup: String, count: Int = 12) -> [ArticulationPose] {
        let pool = catalog.filter { pose in
            switch soundGroup {
            case SoundFamily.whistling.rawValue:
                return ["С", "З", "Ц", "И", "Э", "Ы"].contains(pose.targetSound)
            case SoundFamily.hissing.rawValue:
                return ["Ш", "О", "У", "П"].contains(pose.targetSound)
            case SoundFamily.sonorant.rawValue:
                return ["Р", "Л", "А", "М"].contains(pose.targetSound)
            case SoundFamily.velar.rawValue:
                return ["А", "О", "И", "У", "Э"].contains(pose.targetSound)
            default:
                return true
            }
        }
        let working = pool.isEmpty ? catalog : pool
        let sorted = working.sorted { $0.id < $1.id }
        return Array(sorted.prefix(count))
    }
}

// MARK: - PoseMatchResult

/// Результат сравнения текущих blendshapes с целевыми значениями позы.
struct PoseMatchResult: Sendable {
    /// Итоговый скор 0–100.
    let score: Int
    /// Успех (score ≥ 75).
    let isSuccess: Bool
    /// Канал с наибольшим отклонением (для feedback).
    let weakestChannel: String?
    /// Активированные каналы (score вклад > 0.5).
    let matchedChannels: [String]
}

// MARK: - MirroringMode

/// Режим зеркала: AR-режим (TrueDepth) или 2D fallback.
enum MirroringMode: Sendable, Equatable {
    case arFaceTracking
    case fallback2D
}

// MARK: - ArticulationGamePhase

/// Фазы игры «Зеркало».
enum ArticulationGamePhase: Sendable, Equatable {
    case loading
    case posePreview
    case mirroring
    case poseFeedback
    case hintShowing(level: Int)
    case parentConfirm
    case completed
}

// MARK: - PerPoseRecord

/// Запись точности по каждой позе за сессию.
struct PerPoseRecord: Sendable {
    let poseId: String
    let attempts: Int
    let bestScore: Int
    let passed: Bool
}

// MARK: - VIP Envelopes

enum ArticulationImitationModels {

    // MARK: LoadSession
    enum LoadSession {
        struct Request: Sendable {
            let soundGroup: String
            let childName: String
        }
        struct Response: Sendable {
            let poses: [ArticulationPose]
            let childName: String
            let mirroringMode: MirroringMode
        }
        struct ViewModel: Sendable {
            let poses: [ArticulationPose]
            let greeting: String
            let mirroringMode: MirroringMode
            // Обратная совместимость со старым полем exercises
            var exercises: [ArticulationExercise] { [] }
        }
    }

    // MARK: StartPose
    enum StartPose {
        struct Request: Sendable {
            let poseIndex: Int
        }
        struct Response: Sendable {
            let pose: ArticulationPose
            let poseNumber: Int
            let total: Int
            let attemptNumber: Int
        }
        struct ViewModel: Sendable {
            let pose: ArticulationPose
            let progressLabel: String
            let attemptLabel: String
            let voicePrompt: String
        }
    }

    // MARK: StartExercise (обратная совместимость)
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

    // MARK: BlendshapeUpdate
    enum BlendshapeUpdate {
        struct Request: Sendable {
            let jawOpen: Float
            let jawForward: Float
            let mouthFunnel: Float
            let mouthPucker: Float
            let mouthSmileLeft: Float
            let mouthSmileRight: Float
            let mouthFrownLeft: Float
            let mouthFrownRight: Float
            let mouthRollLower: Float
            let mouthRollUpper: Float
            let mouthStretchLeft: Float
            let mouthStretchRight: Float
            let mouthLowerDownLeft: Float
            let mouthLowerDownRight: Float
            let mouthUpperUpLeft: Float
            let mouthUpperUpRight: Float
            let mouthClose: Float
            let tongueOut: Float
        }
        struct Response: Sendable {
            let matchResult: PoseMatchResult
            let pose: ArticulationPose
        }
        struct ViewModel: Sendable {
            let scoreFraction: Double
            let scoreLabel: String
            let feedbackColor: String
            let matchedChannels: [String]
        }
    }

    // MARK: HoldProgress (обратная совместимость)
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

    // MARK: ConfirmPose
    enum ConfirmPose {
        struct Request: Sendable {
            let poseId: String
            let confirmedByParent: Bool
        }
        struct Response: Sendable {
            let passed: Bool
            let score: Int
            let nextPoseIndex: Int?
            let allDone: Bool
        }
        struct ViewModel: Sendable {
            let passed: Bool
            let feedbackText: String
            let scoreLabel: String
            let allDone: Bool
        }
    }

    // MARK: CompleteExercise (обратная совместимость)
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

    // MARK: RequestHint
    enum RequestHint {
        struct Request: Sendable {
            let poseId: String
        }
        struct Response: Sendable {
            let hintText: String
            let hintLevel: Int
            let attemptsLeft: Int
        }
        struct ViewModel: Sendable {
            let hintText: String
            let hintLevel: Int
            let attemptsLeftLabel: String
        }
    }

    // MARK: SessionComplete
    enum SessionComplete {
        struct Request: Sendable {}
        struct Response: Sendable {
            let starsTotal: Int
            let outOf: Int
            let perPoseRecords: [PerPoseRecord]
        }
        struct ViewModel: Sendable {
            let starsTotal: Int
            let outOf: Int
            let scoreLabel: String
            let message: String
            let normalizedScore: Float
            let showDetailedStats: Bool
        }
    }
}

// MARK: - ArticulationExercise (обратная совместимость)

struct ArticulationExercise: Sendable, Identifiable, Equatable {
    let id: String
    let name: String
    let instruction: String
    let targetSound: String
    let holdSeconds: Int
    let emoji: String
    let systemImageName: String

    static let catalog: [ArticulationExercise] = []

    static func exercises(for soundGroup: String, count: Int = 5) -> [ArticulationExercise] {
        return []
    }
}

// MARK: - ArticulationPhase (обратная совместимость)

enum ArticulationPhase: Sendable, Equatable {
    case loading
    case exercisePreview
    case holding
    case feedback
    case completed
}

// MARK: - Display store

/// `@Observable` store, к которому подписан View.
@MainActor
@Observable
final class ArticulationImitationDisplay {

    // Legacy fields (обратная совместимость)
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
    var outOf: Int = 12
    var scoreLabel: String = ""
    var completionMessage: String = ""
    var phase: ArticulationPhase = .loading
    var pendingFinalScore: Float?

    // New deep fields
    var currentPose: ArticulationPose?
    var poseNumber: Int = 0
    var totalPoses: Int = 0
    var attemptLabel: String = ""
    var voicePrompt: String = ""
    var mirroringMode: MirroringMode = .fallback2D
    var gamePhase: ArticulationGamePhase = .loading
    var liveScoreFraction: Double = 0
    var liveScoreLabel: String = ""
    var liveFeedbackColor: String = "neutral"
    var matchedChannels: [String] = []
    var hintText: String = ""
    var hintLevel: Int = 0
    var attemptsLeftLabel: String = ""
    var poseFeedbackText: String = ""
    var posePassed: Bool = false
    var perPoseRecords: [PerPoseRecord] = []
    var showDetailedStats: Bool = false
    var arSessionActive: Bool = false
}
