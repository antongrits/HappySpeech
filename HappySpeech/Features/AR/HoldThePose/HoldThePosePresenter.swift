import Foundation

@MainActor
protocol HoldThePosePresentationLogic: AnyObject {
    func presentStartGame(_ response: HoldThePoseModels.StartGame.Response)
    func presentUpdateFrame(_ response: HoldThePoseModels.UpdateFrame.Response)
    func presentScoreAttempt(_ response: HoldThePoseModels.ScoreAttempt.Response)
}

@MainActor
protocol HoldThePoseDisplayLogic: AnyObject {
    func displayStartGame(_ viewModel: HoldThePoseModels.StartGame.ViewModel)
    func displayUpdateFrame(_ viewModel: HoldThePoseModels.UpdateFrame.ViewModel)
    func displayScoreAttempt(_ viewModel: HoldThePoseModels.ScoreAttempt.ViewModel)
}

@MainActor
final class HoldThePosePresenter: HoldThePosePresentationLogic {

    weak var display: (any HoldThePoseDisplayLogic)?
    private var holdTarget: TimeInterval = 5

    func presentStartGame(_ response: HoldThePoseModels.StartGame.Response) {
        holdTarget = response.holdDurationSec
        display?.displayStartGame(.init(
            postureName: response.targetPosture.displayName,
            holdTargetText: String(format: "%.0f сек", response.holdDurationSec)
        ))
    }

    func presentUpdateFrame(_ response: HoldThePoseModels.UpdateFrame.Response) {
        let progress = min(1, Float(response.heldSeconds / holdTarget))
        display?.displayUpdateFrame(.init(
            progress: progress,
            confidencePercent: Int(response.confidence * 100)
        ))
    }

    func presentScoreAttempt(_ response: HoldThePoseModels.ScoreAttempt.Response) {
        let msg = String(format: String(localized: "ar.holdPose.result"), response.heldSeconds)
        display?.displayScoreAttempt(.init(stars: response.stars, message: msg))
    }
}
