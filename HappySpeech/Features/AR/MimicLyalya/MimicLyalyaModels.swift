import Foundation

enum MimicLyalyaModels {

    enum StartGame {
        struct Request { let rounds: Int }
        struct Response { let targetPosture: ArticulationPosture; let roundNumber: Int; let totalRounds: Int }
        struct ViewModel { let postureName: String; let mascotHint: String; let roundText: String }
    }

    enum UpdateFrame {
        struct Request { let blendshapes: FaceBlendshapes }
        struct Response { let confidence: Float; let isMatching: Bool }
        struct ViewModel { let progress: Float; let emoji: String }
    }

    enum ScoreAttempt {
        struct Request { let confidence: Float }
        struct Response { let stars: Int }
        struct ViewModel { let stars: Int; let message: String }
    }
}
