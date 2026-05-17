import Foundation

// MARK: - RepeatAfterModelPresentationLogic

@MainActor
protocol RepeatAfterModelPresentationLogic: AnyObject {
    func presentLoadSession(_ response: RepeatAfterModelModels.LoadSession.Response)
    func presentStartWord(_ response: RepeatAfterModelModels.StartWord.Response)
    func presentRecordAttempt(_ response: RepeatAfterModelModels.RecordAttempt.Response)
    func presentEvaluateAttempt(_ response: RepeatAfterModelModels.EvaluateAttempt.Response)
    func presentReplayModel(_ response: RepeatAfterModelModels.ReplayModel.Response)
    func presentHint(_ response: RepeatAfterModelModels.Hint.Response)
    func presentSloMo(_ response: RepeatAfterModelModels.SloMo.Response)
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
            attemptsLeft: response.attemptsLeft,
            syllabification: response.word.syllabification,
            canReplay: response.canReplay,
            replayCount: response.replayCount
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

        let diagnosticText: String? = buildDiagnosticText(response.diagnostic)
        let hintAvailable = response.hintLevel != RepeatHintLevel.sloMoReplay

        let vm = RepeatAfterModelModels.EvaluateAttempt.ViewModel(
            score: response.score,
            passed: response.passed,
            feedbackText: response.feedback,
            attemptsLabel: attemptsLabel,
            canAdvance: response.canAdvance,
            diagnosticText: diagnosticText,
            encouragement: response.encouragement,
            hintAvailable: hintAvailable,
            stars: response.stars,
            attemptsLeft: response.attemptsLeft
        )
        viewModel?.displayEvaluateAttempt(vm)
    }

    private func buildDiagnosticText(_ diagnostic: PronunciationDiagnostic) -> String? {
        switch diagnostic {
        case .none:         return nil
        case .distortion:   return String(localized: "repeat.diagnostic.distortion")
        case .substitution: return String(localized: "repeat.diagnostic.substitution")
        case .omission:     return String(localized: "repeat.diagnostic.omission")
        case .addition:     return String(localized: "repeat.diagnostic.addition")
        }
    }

    // MARK: - ReplayModel

    func presentReplayModel(_ response: RepeatAfterModelModels.ReplayModel.Response) {
        let replayLabel: String
        if response.replayLimitReached {
            replayLabel = String(localized: "repeat.replay.limit_reached")
        } else {
            let template = String(localized: "repeat.replay.count_format")
            replayLabel = String(format: template, response.replayCount)
        }
        let vm = RepeatAfterModelModels.ReplayModel.ViewModel(
            audioFilename: response.audioFilename,
            replayCount: response.replayCount,
            replayLimitReached: response.replayLimitReached,
            replayLabel: replayLabel
        )
        viewModel?.displayReplayModel(vm)
    }

    // MARK: - Hint

    func presentHint(_ response: RepeatAfterModelModels.Hint.Response) {
        let hintLabel: String
        switch response.hintLevel {
        case RepeatHintLevel.none:
            hintLabel = ""
        case RepeatHintLevel.syllabification:
            hintLabel = String(localized: "repeat.hint.syllabification")
        case RepeatHintLevel.articulationDiagram:
            hintLabel = String(localized: "repeat.hint.articulation")
        case RepeatHintLevel.sloMoReplay:
            hintLabel = String(localized: "repeat.hint.slomo")
        }
        let vm = RepeatAfterModelModels.Hint.ViewModel(
            hintLevel: response.hintLevel,
            syllabificationText: response.syllabification,
            articulationAsset: response.articulationAsset,
            hintLabel: hintLabel
        )
        viewModel?.displayHint(vm)
    }

    // MARK: - SloMo

    func presentSloMo(_ response: RepeatAfterModelModels.SloMo.Response) {
        let ratePercent = Int(response.playbackRate * 100)
        let template = String(localized: "repeat.slomo.rate_format")
        let label = String(format: template, ratePercent)
        let vm = RepeatAfterModelModels.SloMo.ViewModel(
            audioFilename: response.audioFilename,
            playbackRate: response.playbackRate,
            sloMoLabel: label
        )
        viewModel?.displaySloMo(vm)
    }

    // MARK: - CompleteSession

    func presentCompleteSession(_ response: RepeatAfterModelModels.CompleteSession.Response) {
        let scoreTemplate = String(localized: "repeat.score.format")
        let scorePercent = Int((response.totalScore * 100).rounded())
        let scoreLabel = String(format: scoreTemplate, scorePercent)

        let message: String
        switch response.totalScore {
        case 0.80...:
            message = String(localized: "repeat.message.excellent")
        case 0.60..<0.80:
            message = String(localized: "repeat.message.good")
        case 0.40..<0.60:
            message = String(localized: "repeat.message.keep_going")
        default:
            message = String(localized: "repeat.message.try_again")
        }

        let statsTemplate = String(localized: "repeat.stats.format")
        let statsLabel = String(
            format: statsTemplate,
            response.wordsCompleted,
            response.totalAttempts,
            response.wordsWithPerfectScore
        )

        let vm = RepeatAfterModelModels.CompleteSession.ViewModel(
            starsEarned: response.starsEarned,
            scoreLabel: scoreLabel,
            message: message,
            normalizedScore: max(0, min(response.totalScore, 1)),
            statsLabel: statsLabel
        )
        viewModel?.displayCompleteSession(vm)
    }
}
