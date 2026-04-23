import Foundation

enum SoundAndFaceModels {

    struct Target: Sendable {
        let sound: String
        let posture: ArticulationPosture
    }

    enum StartGame {
        struct Request { let targetSound: String }
        struct Response { let target: Target }
        struct ViewModel { let soundText: String; let postureName: String; let instruction: String }
    }

    enum UpdateFrame {
        struct Request { let blendshapes: FaceBlendshapes }
        struct Response { let postureConfidence: Float }
        struct ViewModel { let postureProgress: Float }
    }

    enum ScoreAttempt {
        struct Request { let asrTranscript: String; let avgPostureConfidence: Float }
        struct Response { let stars: Int; let transcriptMatched: Bool }
        struct ViewModel { let stars: Int; let feedback: String }
    }
}
