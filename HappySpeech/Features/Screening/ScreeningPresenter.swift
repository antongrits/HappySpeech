import Foundation

// MARK: - ScreeningPresentationLogic

@MainActor
protocol ScreeningPresentationLogic: AnyObject {
    func presentStartScreening(_ response: ScreeningModels.StartScreening.Response) async
    func presentSubmitAnswer(_ response: ScreeningModels.SubmitAnswer.Response) async
    func presentFinishScreening(_ response: ScreeningModels.FinishScreening.Response) async
}

// MARK: - ScreeningPresenter

@MainActor
final class ScreeningPresenter: ScreeningPresentationLogic {

    weak var display: (any ScreeningDisplayLogic)?

    func presentStartScreening(_ response: ScreeningModels.StartScreening.Response) async {
        let estMinutes = max(1, response.prompts.count / 2)
        let vm = ScreeningModels.StartScreening.ViewModel(
            prompts: response.prompts,
            progressText: String(localized: "screening.header.progress.\(response.prompts.count)"),
            estimatedMinutes: estMinutes
        )
        display?.displayStartScreening(vm)
    }

    func presentSubmitAnswer(_ response: ScreeningModels.SubmitAnswer.Response) async {
        let vm = ScreeningModels.SubmitAnswer.ViewModel(
            nextPromptIndex: response.isScreeningComplete ? nil : response.currentPromptIndex + 1,
            shouldShowBlockTransition: response.isBlockComplete,
            shouldShowSummary: response.isScreeningComplete
        )
        display?.displaySubmitAnswer(vm)
    }

    func presentFinishScreening(_ response: ScreeningModels.FinishScreening.Response) async {
        let outcome = response.outcome
        let summary = summaryText(for: outcome)
        let verdicts = outcome.perSound
            .map { (sound, verdict) in
                SoundVerdictViewModel(
                    sound: sound,
                    verdict: verdict,
                    confidencePercent: 100,
                    exampleWord: nil
                )
            }
            .sorted { lhs, rhs in severity(lhs.verdict) > severity(rhs.verdict) }

        let vm = ScreeningModels.FinishScreening.ViewModel(
            outcomeSummary: summary,
            perSoundVerdicts: verdicts,
            recommendedSessionMinutes: outcome.recommendedSessionDurationSec / 60,
            priorityTargetSounds: outcome.priorityTargetSounds
        )
        display?.displayFinishScreening(vm)
    }

    // MARK: - Private

    private func summaryText(for outcome: ScreeningOutcome) -> String {
        if outcome.priorityTargetSounds.isEmpty {
            return String(localized: "screening.summary.all_normal")
        }
        let list = outcome.priorityTargetSounds.joined(separator: ", ")
        return String(localized: "screening.summary.intervention.\(list)")
    }

    private func severity(_ verdict: SoundVerdict) -> Int {
        switch verdict {
        case .normal:       return 0
        case .monitor:      return 1
        case .intervention: return 2
        }
    }
}
