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
            totalRounds: response.totalRounds
        )
        display?.displayLoadExercise(vm)
    }

    func presentSubmitDrawing(_ response: LetterTracingModels.SubmitDrawing.Response) {
        let percent = Int((response.finalScore * 100).rounded())
        let feedbackText: String
        if response.finalScore >= 0.7 {
            feedbackText = String(localized: "letter_tracing.feedback.excellent")
        } else if response.finalScore >= 0.4 {
            feedbackText = String(localized: "letter_tracing.feedback.good")
        } else {
            feedbackText = String(localized: "letter_tracing.feedback.try_again")
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
            canRetry: !response.isCorrect
        )
        display?.displaySubmitDrawing(vm)
    }

    func presentResetCanvas(_ response: LetterTracingModels.ResetCanvas.Response) {
        display?.displayResetCanvas(LetterTracingModels.ResetCanvas.ViewModel())
    }

    func presentCompleteSession(_ response: LetterTracingModels.CompleteSession.Response) {
        let summary = String(
            localized:
                "letter_tracing.session_complete \(response.correctCount) \(response.totalRounds)"
        )
        let vm = LetterTracingModels.CompleteSession.ViewModel(
            summaryText: summary,
            finalScore: Float(response.averageScore)
        )
        display?.displayCompleteSession(vm)
    }
}
