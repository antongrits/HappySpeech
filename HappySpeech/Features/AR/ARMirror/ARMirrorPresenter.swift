import Foundation

// MARK: - ARMirrorPresentationLogic

@MainActor
protocol ARMirrorPresentationLogic: AnyObject {
    func presentStartGame(_ response: ARMirrorModels.StartGame.Response)
    func presentUpdateFrame(_ response: ARMirrorModels.UpdateFrame.Response)
    func presentScoreAttempt(_ response: ARMirrorModels.ScoreAttempt.Response)
}

// MARK: - ARMirrorPresenter

@MainActor
final class ARMirrorPresenter: ARMirrorPresentationLogic {

    weak var display: (any ARMirrorDisplayLogic)?

    func presentStartGame(_ response: ARMirrorModels.StartGame.Response) {
        guard response.exercises.indices.contains(response.currentIndex) else { return }
        let exercise = response.exercises[response.currentIndex]
        let vm = ARMirrorModels.StartGame.ViewModel(
            currentExercise: exercise,
            exerciseNumber: response.currentIndex + 1,
            totalExercises: response.exercises.count,
            instruction: String(localized: String.LocalizationValue(exercise.instructionKey))
        )
        display?.displayStartGame(vm)
    }

    func presentUpdateFrame(_ response: ARMirrorModels.UpdateFrame.Response) {
        let progress = min(1, Float(response.sustainedSeconds) / 3.0)
        let hint = response.confidence < 0.3
        display?.displayUpdateFrame(.init(
            progress: progress,
            hintPulse: hint,
            shouldAdvance: response.didCompleteExercise
        ))
    }

    func presentScoreAttempt(_ response: ARMirrorModels.ScoreAttempt.Response) {
        let msg: String
        switch response.stars {
        case 3: msg = String(localized: "ar.mirror.score.excellent")
        case 2: msg = String(localized: "ar.mirror.score.good")
        case 1: msg = String(localized: "ar.mirror.score.tryAgain")
        default: msg = String(localized: "ar.mirror.score.keepGoing")
        }
        display?.displayScoreAttempt(.init(stars: response.stars, message: msg))
    }
}

// MARK: - ARMirrorDisplayLogic

@MainActor
protocol ARMirrorDisplayLogic: AnyObject {
    func displayStartGame(_ viewModel: ARMirrorModels.StartGame.ViewModel)
    func displayUpdateFrame(_ viewModel: ARMirrorModels.UpdateFrame.ViewModel)
    func displayScoreAttempt(_ viewModel: ARMirrorModels.ScoreAttempt.ViewModel)
}
