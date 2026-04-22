import Foundation

@MainActor
protocol ButterflyCatchPresentationLogic: AnyObject {
    func presentStartGame(_ response: ButterflyCatchModels.StartGame.Response)
    func presentSpawnButterfly(_ response: ButterflyCatchModels.SpawnButterfly.Response)
    func presentScoreAttempt(_ response: ButterflyCatchModels.ScoreAttempt.Response)
}

@MainActor
protocol ButterflyCatchDisplayLogic: AnyObject {
    func displayStartGame(_ viewModel: ButterflyCatchModels.StartGame.ViewModel)
    func displaySpawnButterfly(_ viewModel: ButterflyCatchModels.SpawnButterfly.ViewModel)
    func displayScoreAttempt(_ viewModel: ButterflyCatchModels.ScoreAttempt.ViewModel)
}

@MainActor
final class ButterflyCatchPresenter: ButterflyCatchPresentationLogic {

    weak var display: (any ButterflyCatchDisplayLogic)?

    func presentStartGame(_ response: ButterflyCatchModels.StartGame.Response) {
        display?.displayStartGame(.init(
            totalButterflies: response.totalButterflies,
            timeLeftText: String(format: "%d сек", response.durationSec)
        ))
    }

    func presentSpawnButterfly(_ response: ButterflyCatchModels.SpawnButterfly.Response) {
        display?.displaySpawnButterfly(.init(butterfly: response.butterfly))
    }

    func presentScoreAttempt(_ response: ButterflyCatchModels.ScoreAttempt.Response) {
        display?.displayScoreAttempt(.init(
            caught: response.caught,
            scoreText: String(format: String(localized: "ar.butterfly.score"), response.totalCaught)
        ))
    }
}
