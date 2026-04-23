import Foundation

@MainActor
protocol MimicLyalyaPresentationLogic: AnyObject {
    func presentStartGame(_ response: MimicLyalyaModels.StartGame.Response)
    func presentUpdateFrame(_ response: MimicLyalyaModels.UpdateFrame.Response)
    func presentScoreAttempt(_ response: MimicLyalyaModels.ScoreAttempt.Response)
}

@MainActor
protocol MimicLyalyaDisplayLogic: AnyObject {
    func displayStartGame(_ viewModel: MimicLyalyaModels.StartGame.ViewModel)
    func displayUpdateFrame(_ viewModel: MimicLyalyaModels.UpdateFrame.ViewModel)
    func displayScoreAttempt(_ viewModel: MimicLyalyaModels.ScoreAttempt.ViewModel)
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
            emoji: response.isMatching ? "🎉" : "🙂"
        ))
    }

    func presentScoreAttempt(_ response: MimicLyalyaModels.ScoreAttempt.Response) {
        display?.displayScoreAttempt(.init(
            stars: response.stars,
            message: String(localized: "ar.mimic.roundComplete")
        ))
    }
}
