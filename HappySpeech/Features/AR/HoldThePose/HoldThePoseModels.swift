import Foundation

enum HoldThePoseModels {

    enum StartGame {
        struct Request { let targetPosture: ArticulationPosture; let holdDurationSec: TimeInterval }
        struct Response { let targetPosture: ArticulationPosture; let holdDurationSec: TimeInterval }
        struct ViewModel { let postureName: String; let holdTargetText: String }
    }

    enum ScoreAttempt {
        struct Request { let heldSeconds: TimeInterval; let averageConfidence: Float }
        struct Response { let stars: Int; let heldSeconds: TimeInterval }
        struct ViewModel { let stars: Int; let message: String }
    }

    enum UpdateFrame {
        struct Request { let blendshapes: FaceBlendshapes }
        struct Response { let confidence: Float; let heldSeconds: TimeInterval }
        struct ViewModel { let progress: Float; let confidencePercent: Int }
    }
}
