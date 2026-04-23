import Foundation

@MainActor
protocol SoundAndFacePresentationLogic: AnyObject {
    func presentStartGame(_ response: SoundAndFaceModels.StartGame.Response)
    func presentUpdateFrame(_ response: SoundAndFaceModels.UpdateFrame.Response)
    func presentScoreAttempt(_ response: SoundAndFaceModels.ScoreAttempt.Response)
}

@MainActor
protocol SoundAndFaceDisplayLogic: AnyObject {
    func displayStartGame(_ viewModel: SoundAndFaceModels.StartGame.ViewModel)
    func displayUpdateFrame(_ viewModel: SoundAndFaceModels.UpdateFrame.ViewModel)
    func displayScoreAttempt(_ viewModel: SoundAndFaceModels.ScoreAttempt.ViewModel)
}

@MainActor
final class SoundAndFacePresenter: SoundAndFacePresentationLogic {

    weak var display: (any SoundAndFaceDisplayLogic)?

    func presentStartGame(_ response: SoundAndFaceModels.StartGame.Response) {
        display?.displayStartGame(.init(
            soundText: response.target.sound,
            postureName: response.target.posture.displayName,
            instruction: String(localized: "ar.soundFace.instruction")
        ))
    }

    func presentUpdateFrame(_ response: SoundAndFaceModels.UpdateFrame.Response) {
        display?.displayUpdateFrame(.init(postureProgress: response.postureConfidence))
    }

    func presentScoreAttempt(_ response: SoundAndFaceModels.ScoreAttempt.Response) {
        let key = response.transcriptMatched ? "ar.soundFace.matched" : "ar.soundFace.missed"
        display?.displayScoreAttempt(.init(stars: response.stars, feedback: String(localized: String.LocalizationValue(key))))
    }
}
