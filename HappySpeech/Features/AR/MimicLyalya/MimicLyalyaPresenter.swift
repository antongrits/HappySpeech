import Foundation

@MainActor
protocol MimicLyalyaPresentationLogic: AnyObject {
    func presentStartGame(_ response: MimicLyalyaModels.StartGame.Response)
    func presentUpdateFrame(_ response: MimicLyalyaModels.UpdateFrame.Response)
    func presentScoreAttempt(_ response: MimicLyalyaModels.ScoreAttempt.Response)
    // Block J: Hand Pose
    func presentHandPoseUpdate(_ response: MimicLyalyaModels.UpdateHandPose.Response)
}

@MainActor
protocol MimicLyalyaDisplayLogic: AnyObject {
    func displayStartGame(_ viewModel: MimicLyalyaModels.StartGame.ViewModel)
    func displayUpdateFrame(_ viewModel: MimicLyalyaModels.UpdateFrame.ViewModel)
    func displayScoreAttempt(_ viewModel: MimicLyalyaModels.ScoreAttempt.ViewModel)
    // Block J: Hand Pose
    func displayHandPoseUpdate(_ viewModel: MimicLyalyaModels.UpdateHandPose.ViewModel)
}

@MainActor
final class MimicLyalyaPresenter: MimicLyalyaPresentationLogic {

    weak var display: (any MimicLyalyaDisplayLogic)?

    func presentStartGame(_ response: MimicLyalyaModels.StartGame.Response) {
        display?.displayStartGame(.init(
            postureName: response.targetPosture.displayName,
            mascotHint: String(localized: "ar.mimic.mascotHint"),
            roundText: "\(response.roundNumber) / \(response.totalRounds)"
        ))
    }

    func presentUpdateFrame(_ response: MimicLyalyaModels.UpdateFrame.Response) {
        display?.displayUpdateFrame(.init(
            progress: response.confidence,
            emoji: response.isMatching ? "party.popper.fill" : "face.smiling"
        ))
    }

    func presentScoreAttempt(_ response: MimicLyalyaModels.ScoreAttempt.Response) {
        display?.displayScoreAttempt(.init(
            stars: response.stars,
            message: String(localized: "ar.mimic.roundComplete")
        ))
    }

    // MARK: - Block J: Hand Pose

    func presentHandPoseUpdate(_ response: MimicLyalyaModels.UpdateHandPose.Response) {
        let hintKey: String
        let poseNameKey: String

        if let target = response.targetPose {
            hintKey = response.isMatching
                ? "hand_pose.detect.matched"
                : "hand_pose.detect.hint"
            poseNameKey = handPoseLocKey(target)
        } else {
            hintKey = "hand_pose.detect.hint"
            poseNameKey = handPoseLocKey(response.detectedPose)
        }

        display?.displayHandPoseUpdate(.init(
            hintKey: hintKey,
            isMatching: response.isMatching,
            poseNameKey: poseNameKey
        ))
    }

    // MARK: - Private helpers

    private func handPoseLocKey(_ pose: HandPose) -> String {
        switch pose {
        case .openPalm:  return "hand_pose.open_palm"
        case .fist:      return "hand_pose.fist"
        case .point:     return "hand_pose.point"
        case .pinch:     return "hand_pose.pinch"
        case .wave:      return "hand_pose.wave"
        case .thumbsUp:  return "hand_pose.thumbs_up"
        case .unknown:   return "hand_pose.detect.hint"
        }
    }
}
