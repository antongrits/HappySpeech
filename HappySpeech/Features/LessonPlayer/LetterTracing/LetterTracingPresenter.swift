import Foundation

// MARK: - LetterTracingPresenter

@MainActor
final class LetterTracingPresenter: LetterTracingPresentationLogic {

    weak var display: (any LetterTracingDisplayLogic)?

    // MARK: - LetterTracingPresentationLogic

    func presentLoadExercise(_ response: LetterTracingModels.LoadExercise.Response) {
        let instruction = String(
            localized: "letter_tracing.instruction \(response.targetLetter)"
        )
        let progress = String(
            localized:
                "letter_tracing.progress \(response.roundIndex + 1) \(response.totalRounds)"
        )
        let vm = LetterTracingModels.LoadExercise.ViewModel(
            targetLetter: response.targetLetter,
            instructionText: instruction,
            progressText: progress,
            roundIndex: response.roundIndex,
            totalRounds: response.totalRounds,
            tracingLevel: response.tracingLevel,
            hintState: response.hintState,
            strokeCount: response.strokeCount,
            phonemeWord: response.phonemeWord,
            voicePrompt: response.promptText
        )
        display?.displayLoadExercise(vm)
    }

    func presentSubmitDrawing(_ response: LetterTracingModels.SubmitDrawing.Response) {
        let percent = Int((response.finalScore * 100).rounded())
        let bestPercent = Int((response.bestScore * 100).rounded())
        let feedbackText: String
        let voiceFeedback: String
        if response.finalScore >= 0.85 {
            feedbackText = String(localized: "letter_tracing.feedback.excellent")
            voiceFeedback = String(localized: "letter_tracing.voice.excellent \(response.targetLetter)")
        } else if response.finalScore >= 0.65 {
            feedbackText = String(localized: "letter_tracing.feedback.good")
            voiceFeedback = String(localized: "letter_tracing.voice.good")
        } else if response.finalScore >= 0.4 {
            feedbackText = String(localized: "letter_tracing.feedback.try_again")
            voiceFeedback = String(localized: "letter_tracing.voice.try_again")
        } else {
            feedbackText = String(localized: "letter_tracing.feedback.try_again")
            voiceFeedback = String(localized: "letter_tracing.voice.encourage")
        }

        let recognizedText: String?
        if let recognized = response.recognizedLetter {
            recognizedText = String(
                localized: "letter_tracing.recognized \(recognized)"
            )
        } else {
            recognizedText = nil
        }

        let vm = LetterTracingModels.SubmitDrawing.ViewModel(
            feedbackText: feedbackText,
            scorePercent: percent,
            isCorrect: response.isCorrect,
            recognizedText: recognizedText,
            canRetry: !response.isCorrect,
            attemptNumber: response.attemptNumber,
            bestScorePercent: bestPercent,
            voiceFeedback: voiceFeedback
        )
        display?.displaySubmitDrawing(vm)
    }

    func presentResetCanvas(_ response: LetterTracingModels.ResetCanvas.Response) {
        display?.displayResetCanvas(LetterTracingModels.ResetCanvas.ViewModel())
    }

    func presentRequestHint(_ response: LetterTracingModels.RequestHint.Response) {
        let hintText: String
        let showStart: Bool
        let showArrow: Bool
        let showTemplate: Bool
        switch response.hintState {
        case .none:
            hintText = ""
            showStart = false
            showArrow = false
            showTemplate = false
        case .startPoint:
            hintText = String(localized: "letter_tracing.hint.start_point")
            showStart = true
            showArrow = false
            showTemplate = false
        case .direction:
            hintText = String(localized: "letter_tracing.hint.direction")
            showStart = false
            showArrow = true
            showTemplate = false
        case .fullTemplate:
            hintText = String(localized: "letter_tracing.hint.full_template")
            showStart = false
            showArrow = false
            showTemplate = true
        }
        let vm = LetterTracingModels.RequestHint.ViewModel(
            hintState: response.hintState,
            hintText: hintText,
            showStartDot: showStart,
            showDirectionArrow: showArrow,
            showFullTemplate: showTemplate
        )
        display?.displayRequestHint(vm)
    }

    func presentCompleteSession(_ response: LetterTracingModels.CompleteSession.Response) {
        let summary = String(
            localized:
                "letter_tracing.session_complete \(response.correctCount) \(response.totalRounds)"
        )
        let achievedText: String
        if response.achievedLetters.isEmpty {
            achievedText = ""
        } else {
            let joined = response.achievedLetters.joined(separator: ", ")
            achievedText = String(localized: "letter_tracing.achieved \(joined)")
        }
        let celebrationText: String
        if response.averageScore >= 0.8 {
            celebrationText = String(localized: "letter_tracing.celebration.great")
        } else if response.averageScore >= 0.5 {
            celebrationText = String(localized: "letter_tracing.celebration.good")
        } else {
            celebrationText = String(localized: "letter_tracing.celebration.keep_going")
        }
        let vm = LetterTracingModels.CompleteSession.ViewModel(
            summaryText: summary,
            finalScore: Float(response.averageScore),
            achievedText: achievedText,
            celebrationText: celebrationText
        )
        display?.displayCompleteSession(vm)
    }
}
