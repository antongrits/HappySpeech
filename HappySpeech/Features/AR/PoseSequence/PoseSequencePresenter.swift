import Foundation

@MainActor
protocol PoseSequencePresentationLogic: AnyObject {
    func presentStartGame(_ response: PoseSequenceModels.StartGame.Response)
    func presentUpdateFrame(_ response: PoseSequenceModels.UpdateFrame.Response)
    func presentScoreAttempt(_ response: PoseSequenceModels.ScoreAttempt.Response)
}

@MainActor
protocol PoseSequenceDisplayLogic: AnyObject {
    func displayStartGame(_ viewModel: PoseSequenceModels.StartGame.ViewModel)
    func displayUpdateFrame(_ viewModel: PoseSequenceModels.UpdateFrame.ViewModel)
    func displayScoreAttempt(_ viewModel: PoseSequenceModels.ScoreAttempt.ViewModel)
}

@MainActor
final class PoseSequencePresenter: PoseSequencePresentationLogic {

    weak var display: (any PoseSequenceDisplayLogic)?
    private var total: Int = 1

    func presentStartGame(_ response: PoseSequenceModels.StartGame.Response) {
        total = response.postures.count
        let names = response.postures.map(\.displayName)
        let current = response.postures.indices.contains(response.currentIndex)
            ? response.postures[response.currentIndex].displayName
            : ""
        display?.displayStartGame(.init(
            postureNames: names,
            currentIndex: response.currentIndex,
            currentName: current
        ))
    }

    func presentUpdateFrame(_ response: PoseSequenceModels.UpdateFrame.Response) {
        let progress = Float(response.currentIndex) / Float(max(total, 1))
        display?.displayUpdateFrame(.init(progress: progress, advanced: response.advanced))
    }

    func presentScoreAttempt(_ response: PoseSequenceModels.ScoreAttempt.Response) {
        display?.displayScoreAttempt(.init(
            stars: response.stars,
            summary: String(localized: "ar.poseSequence.complete")
        ))
    }
}
