import Foundation

// MARK: - ArticulationImitationPresentationLogic

@MainActor
protocol ArticulationImitationPresentationLogic: AnyObject {

    // MARK: Deep VIP
    func presentLoadSession(_ response: ArticulationImitationModels.LoadSession.Response)
    func presentStartPose(_ response: ArticulationImitationModels.StartPose.Response)
    func presentBeginMirroring(_ mode: MirroringMode)
    func presentBlendshapeUpdate(_ response: ArticulationImitationModels.BlendshapeUpdate.Response)
    func presentConfirmPose(_ response: ArticulationImitationModels.ConfirmPose.Response)
    func presentHint(_ response: ArticulationImitationModels.RequestHint.Response)
    func presentParentConfirmRequest(_ pose: ArticulationPose)
    func presentSessionComplete(_ response: ArticulationImitationModels.SessionComplete.Response)

    // MARK: Legacy
    func presentStartExercise(_ response: ArticulationImitationModels.StartExercise.Response)
    func presentHoldProgress(_ response: ArticulationImitationModels.HoldProgress.Response)
    func presentCompleteExercise(_ response: ArticulationImitationModels.CompleteExercise.Response)
}

// MARK: - ArticulationImitationPresenter

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
            poses: response.poses,
            greeting: greeting,
            mirroringMode: response.mirroringMode
        )
        viewModel?.displayLoadSession(vm)
    }

    // MARK: - StartPose

    func presentStartPose(_ response: ArticulationImitationModels.StartPose.Response) {
        let progressTemplate = String(localized: "articulation.progress.format")
        let progressLabel = String(
            format: progressTemplate,
            response.poseNumber,
            response.total
        )
        let attemptTemplate = String(localized: "articulation.attempt.format")
        let attemptLabel = String(format: attemptTemplate, response.attemptNumber)
        let vm = ArticulationImitationModels.StartPose.ViewModel(
            pose: response.pose,
            progressLabel: progressLabel,
            attemptLabel: attemptLabel,
            voicePrompt: response.pose.voicePrompt
        )
        viewModel?.displayStartPose(vm)
    }

    // MARK: - BeginMirroring

    func presentBeginMirroring(_ mode: MirroringMode) {
        viewModel?.displayBeginMirroring(mode)
    }

    // MARK: - BlendshapeUpdate

    func presentBlendshapeUpdate(_ response: ArticulationImitationModels.BlendshapeUpdate.Response) {
        let fraction = Double(response.matchResult.score) / 100.0
        let scoreLabel = "\(response.matchResult.score)%"
        let feedbackColor: String
        switch response.matchResult.score {
        case 75...:  feedbackColor = "success"
        case 50..<75: feedbackColor = "warning"
        default:     feedbackColor = "neutral"
        }
        let vm = ArticulationImitationModels.BlendshapeUpdate.ViewModel(
            scoreFraction: fraction,
            scoreLabel: scoreLabel,
            feedbackColor: feedbackColor,
            matchedChannels: response.matchResult.matchedChannels
        )
        viewModel?.displayBlendshapeUpdate(vm)
    }

    // MARK: - ConfirmPose

    func presentConfirmPose(_ response: ArticulationImitationModels.ConfirmPose.Response) {
        let feedback: String
        if response.passed {
            feedback = String(localized: "articulation.feedback.pose_passed")
        } else {
            feedback = String(localized: "articulation.feedback.pose_failed")
        }
        let scoreLabel = "\(response.score)%"
        let vm = ArticulationImitationModels.ConfirmPose.ViewModel(
            passed: response.passed,
            feedbackText: feedback,
            scoreLabel: scoreLabel,
            allDone: response.allDone
        )
        viewModel?.displayConfirmPose(vm)
    }

    // MARK: - Hint

    func presentHint(_ response: ArticulationImitationModels.RequestHint.Response) {
        let attemptsTemplate = String(localized: "articulation.attempts_left.format")
        let attemptsLabel = String(format: attemptsTemplate, response.attemptsLeft)
        let vm = ArticulationImitationModels.RequestHint.ViewModel(
            hintText: response.hintText,
            hintLevel: response.hintLevel,
            attemptsLeftLabel: attemptsLabel
        )
        viewModel?.displayHint(vm)
    }

    // MARK: - ParentConfirmRequest

    func presentParentConfirmRequest(_ pose: ArticulationPose) {
        viewModel?.displayParentConfirmRequest(pose)
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

        let showDetailed = response.perPoseRecords.count >= 3
        let vm = ArticulationImitationModels.SessionComplete.ViewModel(
            starsTotal: response.starsTotal,
            outOf: outOf,
            scoreLabel: scoreLabel,
            message: message,
            normalizedScore: max(0, min(normalized, 1)),
            showDetailedStats: showDetailed
        )
        viewModel?.displaySessionComplete(vm)
    }

    // MARK: - Legacy: StartExercise

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

    // MARK: - Legacy: HoldProgress

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

    // MARK: - Legacy: CompleteExercise

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
}
