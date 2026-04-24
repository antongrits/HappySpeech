import Foundation

// MARK: - RepeatAfterModelPresentationLogic

@MainActor
protocol RepeatAfterModelPresentationLogic: AnyObject {
    func presentLoadSession(_ response: RepeatAfterModelModels.LoadSession.Response)
    func presentStartWord(_ response: RepeatAfterModelModels.StartWord.Response)
    func presentRecordAttempt(_ response: RepeatAfterModelModels.RecordAttempt.Response)
    func presentEvaluateAttempt(_ response: RepeatAfterModelModels.EvaluateAttempt.Response)
    func presentCompleteSession(_ response: RepeatAfterModelModels.CompleteSession.Response)
}

// MARK: - RepeatAfterModelPresenter

@MainActor
final class RepeatAfterModelPresenter: RepeatAfterModelPresentationLogic {

    weak var viewModel: (any RepeatAfterModelDisplayLogic)?

    // MARK: - LoadSession

    func presentLoadSession(_ response: RepeatAfterModelModels.LoadSession.Response) {
        let greeting: String
        if response.childName.isEmpty {
            greeting = String(localized: "repeat.greeting.default")
        } else {
            let template = String(localized: "repeat.greeting.named")
            greeting = String(format: template, response.childName)
        }
        let vm = RepeatAfterModelModels.LoadSession.ViewModel(
            totalWords: response.words.count,
            greeting: greeting
        )
        viewModel?.displayLoadSession(vm)
    }

    // MARK: - StartWord

    func presentStartWord(_ response: RepeatAfterModelModels.StartWord.Response) {
        let progressTemplate = String(localized: "repeat.progress.format")
        let progressLabel = String(
            format: progressTemplate,
            response.wordNumber,
            response.total
        )
        let attemptsTemplate = String(localized: "repeat.attempts.format")
        let attemptsLabel = String(format: attemptsTemplate, response.attemptsLeft)

        let vm = RepeatAfterModelModels.StartWord.ViewModel(
            word: response.word,
            progressLabel: progressLabel,
            attemptsLabel: attemptsLabel,
            syllabification: response.word.syllabification
        )
        viewModel?.displayStartWord(vm)
    }

    // MARK: - RecordAttempt

    func presentRecordAttempt(_ response: RepeatAfterModelModels.RecordAttempt.Response) {
        let label = response.isRecording
            ? String(localized: "repeat.mic.listening")
            : String(localized: "repeat.mic.tap_to_record")
        let vm = RepeatAfterModelModels.RecordAttempt.ViewModel(
            isRecording: response.isRecording,
            micLabel: label
        )
        viewModel?.displayRecordAttempt(vm)
    }

    // MARK: - EvaluateAttempt

    func presentEvaluateAttempt(_ response: RepeatAfterModelModels.EvaluateAttempt.Response) {
        let attemptsTemplate = String(localized: "repeat.attempts.format")
        let attemptsLabel = String(format: attemptsTemplate, response.attemptsLeft)
        let vm = RepeatAfterModelModels.EvaluateAttempt.ViewModel(
            score: response.score,
            passed: response.passed,
            feedbackText: response.feedback,
            attemptsLabel: attemptsLabel,
            canAdvance: response.canAdvance
        )
        viewModel?.displayEvaluateAttempt(vm)
    }

    // MARK: - CompleteSession

    func presentCompleteSession(_ response: RepeatAfterModelModels.CompleteSession.Response) {
        let scoreTemplate = String(localized: "repeat.score.format")
        let scorePercent = Int((response.totalScore * 100).rounded())
        let scoreLabel = String(format: scoreTemplate, scorePercent)

        let message: String
        switch response.totalScore {
        case 0.85...:
            message = String(localized: "repeat.message.excellent")
        case 0.65..<0.85:
            message = String(localized: "repeat.message.good")
        case 0.40..<0.65:
            message = String(localized: "repeat.message.keep_going")
        default:
            message = String(localized: "repeat.message.try_again")
        }

        let vm = RepeatAfterModelModels.CompleteSession.ViewModel(
            starsEarned: response.starsEarned,
            scoreLabel: scoreLabel,
            message: message,
            normalizedScore: max(0, min(response.totalScore, 1))
        )
        viewModel?.displayCompleteSession(vm)
    }
}
