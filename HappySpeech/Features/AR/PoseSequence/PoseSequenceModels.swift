import Foundation

enum PoseSequenceModels {

    // MARK: - StartGame

    enum StartGame {
        /// Запрос: массив артикуляционных поз (face-режим) или
        /// пустой массив → игра переключается в body-режим (TargetPosesRepository).
        struct Request { let postures: [ArticulationPosture] }
        struct Response {
            let postures: [ArticulationPosture]
            let currentIndex: Int
            /// Режим игры: face (blendshapes) или body (ARBodyTracking).
            let mode: PoseSequenceMode
            /// Target poses — только для body-режима.
            let targetPoses: [TargetPose]
        }
        struct ViewModel {
            let postureNames: [String]
            let currentIndex: Int
            let currentName: String
            let currentHint: String
            let mode: PoseSequenceMode
        }
    }

    // MARK: - UpdateFrame

    enum UpdateFrame {
        /// Face-режим: blendshapes.
        struct Request { let blendshapes: FaceBlendshapes }
        struct Response { let currentIndex: Int; let confidence: Float; let advanced: Bool }
        struct ViewModel { let progress: Float; let advanced: Bool }
    }

    // MARK: - UpdateBodyPose

    /// Body-режим: новый кадр суставов от BodyPoseWorker.
    enum UpdateBodyPose {
        struct Request {
            let update: BodyPoseUpdate
        }
        struct Response {
            let currentIndex: Int
            let score: Int
            let advanced: Bool
            let currentHint: String
        }
        struct ViewModel {
            let progress: Float
            let score: Int
            let advanced: Bool
            let hintText: String
        }
    }

    // MARK: - ScoreAttempt

    enum ScoreAttempt {
        struct Request { let completedCount: Int; let totalCount: Int }
        struct Response { let stars: Int }
        struct ViewModel { let stars: Int; let summary: String }
    }
}

// MARK: - PoseSequenceMode

/// Режим игры: face-tracking (blendshapes) или body-tracking (суставы).
public enum PoseSequenceMode: Sendable {
    case face
    case body
}
