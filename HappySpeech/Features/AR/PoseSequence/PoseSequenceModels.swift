import Foundation

enum PoseSequenceModels {

    enum StartGame {
        struct Request { let postures: [ArticulationPosture] }
        struct Response { let postures: [ArticulationPosture]; let currentIndex: Int }
        struct ViewModel { let postureNames: [String]; let currentIndex: Int; let currentName: String }
    }

    enum UpdateFrame {
        struct Request { let blendshapes: FaceBlendshapes }
        struct Response { let currentIndex: Int; let confidence: Float; let advanced: Bool }
        struct ViewModel { let progress: Float; let advanced: Bool }
    }

    enum ScoreAttempt {
        struct Request { let completedCount: Int; let totalCount: Int }
        struct Response { let stars: Int }
        struct ViewModel { let stars: Int; let summary: String }
    }
}
