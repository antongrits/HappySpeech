import Foundation

enum BreathingARModels {

    enum StartGame {
        struct Request { let dandelionCount: Int }
        struct Response { let dandelionCount: Int }
        struct ViewModel { let totalText: String }
    }

    enum UpdateFrame {
        struct Request { let blendshapes: FaceBlendshapes; let micAmplitude: Float }
        struct Response { let isBlowing: Bool; let strength: Float }
        struct ViewModel { let isBlowing: Bool; let strength: Float; let hint: String }
    }

    enum ScoreAttempt {
        struct Request { let blownCount: Int; let totalCount: Int }
        struct Response { let stars: Int; let percent: Int }
        struct ViewModel { let stars: Int; let message: String }
    }
}
