import Foundation

// MARK: - ArticulationImitationPresentationLogic

@MainActor
protocol ArticulationImitationPresentationLogic: AnyObject {
    func presentLoadSession(_ response: ArticulationImitationModels.LoadSession.Response)
    func presentStartExercise(_ response: ArticulationImitationModels.StartExercise.Response)
    func presentHoldProgress(_ response: ArticulationImitationModels.HoldProgress.Response)
    func presentCompleteExercise(_ response: ArticulationImitationModels.CompleteExercise.Response)
    func presentSessionComplete(_ response: ArticulationImitationModels.SessionComplete.Response)
}

// MARK: - ArticulationImitationPresenter
//
// Чисто форматирующий слой: превращает Response в ViewModel.
// Тексты — через String Catalog; числовые метки — через String(format:).

@MainActor
final class ArticulationImitationPresenter: ArticulationImitationPresentationLogic {

    weak var viewModel: (any ArticulationImitationDisplayLogic)?

    // MARK: - LoadSession

    func presentLoadSession(_ response: ArticulationImitationModels.LoadSession.Response) {
        let greeting: String
        if response.childName.isEmpty {
            greeting = String(localized: "articulation.greeting.default")
        } else {
            let template = String(localized: "articulation.greeting.named")
            greeting = String(format: template, response.childName)
        }
        let vm = ArticulationImitationModels.LoadSession.ViewModel(
            exercises: response.exercises,
            greeting: greeting
        )
        viewModel?.displayLoadSession(vm)
    }

    // MARK: - StartExercise

    func presentStartExercise(_ response: ArticulationImitationModels.StartExercise.Response) {
        let progressTemplate = String(localized: "articulation.progress.format")
        let progressLabel = String(
            format: progressTemplate,
            response.exerciseNumber,
            response.total
        )
        let vm = ArticulationImitationModels.StartExercise.ViewModel(
            exercise: response.exercise,
            progressLabel: progressLabel,
            canStart: true
        )
        viewModel?.displayStartExercise(vm)
    }

    // MARK: - HoldProgress

    func presentHoldProgress(_ response: ArticulationImitationModels.HoldProgress.Response) {
        let template = String(localized: "articulation.timer.format")
        let timerLabel = String(format: template, response.remainingSeconds)
        let vm = ArticulationImitationModels.HoldProgress.ViewModel(
            fraction: response.fraction,
            timerLabel: timerLabel,
            completed: response.completed
        )
        viewModel?.displayHoldProgress(vm)
    }

    // MARK: - CompleteExercise

    func presentCompleteExercise(_ response: ArticulationImitationModels.CompleteExercise.Response) {
        let feedback: String
        if response.earnedStar {
            feedback = String(localized: "articulation.feedback.earned_star")
        } else {
            feedback = String(localized: "articulation.feedback.try_again")
        }
        let vm = ArticulationImitationModels.CompleteExercise.ViewModel(
            earnedStar: response.earnedStar,
            feedbackText: feedback,
            allDone: response.allDone
        )
        viewModel?.displayCompleteExercise(vm)
    }

    // MARK: - SessionComplete

    func presentSessionComplete(_ response: ArticulationImitationModels.SessionComplete.Response) {
        let outOf = max(response.outOf, 1)
        let normalized = Float(response.starsTotal) / Float(outOf)
        let scoreTemplate = String(localized: "articulation.score.format")
        let scoreLabel = String(format: scoreTemplate, response.starsTotal, outOf)

        let message: String
        switch normalized {
        case 0.85...:
            message = String(localized: "articulation.message.excellent")
        case 0.6..<0.85:
            message = String(localized: "articulation.message.good")
        case 0.3..<0.6:
            message = String(localized: "articulation.message.keep_going")
        default:
            message = String(localized: "articulation.message.try_again")
        }

        let vm = ArticulationImitationModels.SessionComplete.ViewModel(
            starsTotal: response.starsTotal,
            outOf: outOf,
            scoreLabel: scoreLabel,
            message: message,
            normalizedScore: max(0, min(normalized, 1))
        )
        viewModel?.displaySessionComplete(vm)
    }
}
