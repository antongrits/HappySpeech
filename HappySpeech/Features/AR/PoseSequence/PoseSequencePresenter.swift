import Foundation

// MARK: - PoseSequencePresentationLogic

@MainActor
protocol PoseSequencePresentationLogic: AnyObject {
    func presentStartGame(_ response: PoseSequenceModels.StartGame.Response)
    func presentUpdateFrame(_ response: PoseSequenceModels.UpdateFrame.Response)
    func presentUpdateBodyPose(_ response: PoseSequenceModels.UpdateBodyPose.Response)
    func presentScoreAttempt(_ response: PoseSequenceModels.ScoreAttempt.Response)
}

// MARK: - PoseSequenceDisplayLogic

@MainActor
protocol PoseSequenceDisplayLogic: AnyObject {
    func displayStartGame(_ viewModel: PoseSequenceModels.StartGame.ViewModel)
    func displayUpdateFrame(_ viewModel: PoseSequenceModels.UpdateFrame.ViewModel)
    func displayUpdateBodyPose(_ viewModel: PoseSequenceModels.UpdateBodyPose.ViewModel)
    func displayScoreAttempt(_ viewModel: PoseSequenceModels.ScoreAttempt.ViewModel)
}

// MARK: - PoseSequencePresenter

@MainActor
final class PoseSequencePresenter: PoseSequencePresentationLogic {

    weak var display: (any PoseSequenceDisplayLogic)?
    private var total: Int = 1
    private var mode: PoseSequenceMode = .face

    // MARK: - presentStartGame

    func presentStartGame(_ response: PoseSequenceModels.StartGame.Response) {
        total = response.mode == .body ? response.targetPoses.count : response.postures.count
        mode = response.mode

        let names: [String]
        let currentName: String
        let currentHint: String

        switch response.mode {
        case .face:
            names = response.postures.map(\.displayName)
            currentName = response.postures.indices.contains(response.currentIndex)
                ? response.postures[response.currentIndex].displayName
                : ""
            currentHint = ""
        case .body:
            names = response.targetPoses.map(\.name)
            currentName = response.targetPoses.indices.contains(response.currentIndex)
                ? response.targetPoses[response.currentIndex].name
                : ""
            currentHint = response.targetPoses.indices.contains(response.currentIndex)
                ? response.targetPoses[response.currentIndex].hint
                : ""
        }

        display?.displayStartGame(.init(
            postureNames: names,
            currentIndex: response.currentIndex,
            currentName: currentName,
            currentHint: currentHint,
            mode: response.mode
        ))
    }

    // MARK: - presentUpdateFrame (face-mode)

    func presentUpdateFrame(_ response: PoseSequenceModels.UpdateFrame.Response) {
        let progress = Float(response.currentIndex) / Float(max(total, 1))
        display?.displayUpdateFrame(.init(progress: progress, advanced: response.advanced))
    }

    // MARK: - presentUpdateBodyPose (body-mode)

    func presentUpdateBodyPose(_ response: PoseSequenceModels.UpdateBodyPose.Response) {
        let progress = Float(response.currentIndex) / Float(max(total, 1))
        display?.displayUpdateBodyPose(.init(
            progress: progress,
            score: response.score,
            advanced: response.advanced,
            hintText: response.currentHint
        ))
    }

    // MARK: - presentScoreAttempt

    func presentScoreAttempt(_ response: PoseSequenceModels.ScoreAttempt.Response) {
        display?.displayScoreAttempt(.init(
            stars: response.stars,
            summary: String(localized: "ar.poseSequence.complete")
        ))
    }
}
