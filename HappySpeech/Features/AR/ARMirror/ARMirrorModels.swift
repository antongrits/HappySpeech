import Foundation

// MARK: - ARMirror VIP Models

enum ARMirrorModels {

    /// Упражнения в зеркале (стадии одна за другой).
    enum Exercise: String, CaseIterable, Sendable, Hashable {
        case smile, pucker, funnel, jawOpen, tongueOut

        var targetPosture: ArticulationPosture {
            switch self {
            case .smile:     return .smile
            case .pucker:    return .pucker
            case .funnel:    return .cupShape
            case .jawOpen:   return .tongueDown
            case .tongueOut: return .shoveling
            }
        }

        var displayNameKey: String {
            switch self {
            case .smile:     return "ar.mirror.exercise.smile"
            case .pucker:    return "ar.mirror.exercise.pucker"
            case .funnel:    return "ar.mirror.exercise.funnel"
            case .jawOpen:   return "ar.mirror.exercise.jawOpen"
            case .tongueOut: return "ar.mirror.exercise.tongueOut"
            }
        }

        var instructionKey: String {
            switch self {
            case .smile:     return "ar.mirror.instruction.smile"
            case .pucker:    return "ar.mirror.instruction.pucker"
            case .funnel:    return "ar.mirror.instruction.funnel"
            case .jawOpen:   return "ar.mirror.instruction.jawOpen"
            case .tongueOut: return "ar.mirror.instruction.tongueOut"
            }
        }
    }

    // MARK: - StartGame
    enum StartGame {
        struct Request {}
        struct Response {
            let exercises: [Exercise]
            let currentIndex: Int
        }
        struct ViewModel {
            let currentExercise: Exercise
            let exerciseNumber: Int
            let totalExercises: Int
            let instruction: String
        }
    }

    // MARK: - UpdateFrame (per-frame blendshape stream)
    enum UpdateFrame {
        struct Request { let blendshapes: FaceBlendshapes }
        struct Response {
            let currentExercise: Exercise
            let confidence: Float              // 0…1 confidence для targetPosture
            let sustainedSeconds: TimeInterval // сколько секунд confidence >= thresh
            let didCompleteExercise: Bool
        }
        struct ViewModel {
            let progress: Float                // 0…1
            let hintPulse: Bool
            let shouldAdvance: Bool
        }
    }

    // MARK: - ScoreAttempt
    enum ScoreAttempt {
        struct Request { let exercise: Exercise; let averageConfidence: Float }
        struct Response { let stars: Int }     // 0…3
        struct ViewModel { let stars: Int; let message: String }
    }
}
