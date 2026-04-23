import Foundation

@MainActor
protocol BreathingARPresentationLogic: AnyObject {
    func presentStartGame(_ response: BreathingARModels.StartGame.Response)
    func presentUpdateFrame(_ response: BreathingARModels.UpdateFrame.Response)
    func presentScoreAttempt(_ response: BreathingARModels.ScoreAttempt.Response)
}

@MainActor
protocol BreathingARDisplayLogic: AnyObject {
    func displayStartGame(_ viewModel: BreathingARModels.StartGame.ViewModel)
    func displayUpdateFrame(_ viewModel: BreathingARModels.UpdateFrame.ViewModel)
    func displayScoreAttempt(_ viewModel: BreathingARModels.ScoreAttempt.ViewModel)
}

@MainActor
final class BreathingARPresenter: BreathingARPresentationLogic {

    weak var display: (any BreathingARDisplayLogic)?

    func presentStartGame(_ response: BreathingARModels.StartGame.Response) {
        display?.displayStartGame(.init(totalText: String(format: String(localized: "ar.breathing.total"), response.dandelionCount)))
    }

    func presentUpdateFrame(_ response: BreathingARModels.UpdateFrame.Response) {
        let hint = response.isBlowing
            ? String(localized: "ar.breathing.keepBlowing")
            : String(localized: "ar.breathing.startBlowing")
        display?.displayUpdateFrame(.init(
            isBlowing: response.isBlowing,
            strength: response.strength,
            hint: hint
        ))
    }

    func presentScoreAttempt(_ response: BreathingARModels.ScoreAttempt.Response) {
        let msg = String(format: String(localized: "ar.breathing.result"), response.percent)
        display?.displayScoreAttempt(.init(stars: response.stars, message: msg))
    }
}
