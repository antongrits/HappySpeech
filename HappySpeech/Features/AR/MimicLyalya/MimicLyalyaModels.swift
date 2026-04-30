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

    // MARK: - Hand Pose (Block J)

    enum UpdateHandPose {
        struct Request { let observation: HandPoseObservation }
        struct Response {
            let detectedPose: HandPose
            let targetPose: HandPose?
            let isMatching: Bool
            let confidence: Float
        }
        struct ViewModel {
            let hintKey: String       // String Catalog ключ для подсказки
            let isMatching: Bool
            let poseNameKey: String   // String Catalog ключ для имени позы
        }
    }
}
