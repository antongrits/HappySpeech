import Foundation
import SwiftUI

// MARK: - SpeechVisualizationPresentationLogic

@MainActor
protocol SpeechVisualizationPresentationLogic: AnyObject, Sendable {
    func presentLoad(response: SpeechVisualizationModels.Load.Response) async
    func presentSetMode(mode: VisualizationMode) async
    func presentScore(
        response: SpeechVisualizationModels.Score.Response,
        syllables: [KaraokeSyllable]
    ) async
}

// MARK: - SpeechVisualizationPresenter

@MainActor
final class SpeechVisualizationPresenter: SpeechVisualizationPresentationLogic {

    weak var displayLogic: (any SpeechVisualizationDisplayLogic)?

    init(displayLogic: (any SpeechVisualizationDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    func presentLoad(response: SpeechVisualizationModels.Load.Response) async {
        let title = String(localized: "karaoke.title")
        let totalLabel = String(
            format: String(localized: "karaoke.duration.label"),
            response.totalDuration
        )

        let syllableVMs = response.syllables.map { syllable in
            SpeechVisualizationModels.Load.SyllableViewModel(
                id: syllable.id,
                text: syllable.text,
                state: .idle,
                durationSeconds: syllable.durationSeconds,
                accessibilityLabel: String(
                    format: String(localized: "karaoke.syllable.a11y"),
                    syllable.text
                )
            )
        }

        let viewModel = SpeechVisualizationModels.Load.ViewModel(
            title: title,
            wordDisplay: response.word,
            syllables: syllableVMs,
            totalDurationLabel: totalLabel
        )
        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    func presentSetMode(mode: VisualizationMode) async {
        let instruction: String
        let cta: String
        switch mode {
        case .listen:
            instruction = String(localized: "karaoke.instructions.listen")
            cta = String(localized: "karaoke.cta.listen")
        case .practice:
            instruction = String(localized: "karaoke.instructions.practice")
            cta = String(localized: "karaoke.cta.practice")
        }
        let viewModel = SpeechVisualizationModels.SetMode.ViewModel(
            mode: mode,
            instructionText: instruction,
            primaryButtonTitle: cta
        )
        await displayLogic?.displaySetMode(viewModel: viewModel)
    }

    func presentScore(
        response: SpeechVisualizationModels.Score.Response,
        syllables: [KaraokeSyllable]
    ) async {
        let updatedSyllables = zip(syllables, response.perSyllableAccuracy).map { syllable, accuracy in
            let state: KaraokeSyllableState
            switch accuracy {
            case 0.8...:  state = .correct
            case 0.5..<0.8: state = .warning
            default:      state = .incorrect
            }
            return SpeechVisualizationModels.Load.SyllableViewModel(
                id: syllable.id,
                text: syllable.text,
                state: state,
                durationSeconds: syllable.durationSeconds,
                accessibilityLabel: String(
                    format: String(localized: "karaoke.syllable.scored.a11y"),
                    syllable.text,
                    Int(round(accuracy * 100))
                )
            )
        }

        let summaryColor: Color = switch response.overallAccuracy {
        case 0.8...:    KaraokeSyllableState.correct.color
        case 0.5..<0.8: KaraokeSyllableState.warning.color
        default:        KaraokeSyllableState.incorrect.color
        }
        let summaryText = String(
            format: String(localized: "karaoke.summary"),
            Int(round(response.overallAccuracy * 100))
        )

        let viewModel = SpeechVisualizationModels.Score.ViewModel(
            summaryText: summaryText,
            summaryColor: summaryColor,
            updatedSyllables: updatedSyllables,
            confettiBurst: response.overallAccuracy >= 0.8
        )
        await displayLogic?.displayScore(viewModel: viewModel)
    }
}
