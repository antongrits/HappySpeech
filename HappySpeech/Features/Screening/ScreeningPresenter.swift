import Foundation

// MARK: - ScreeningPresentationLogic

@MainActor
protocol ScreeningPresentationLogic: AnyObject {
    func presentStartScreening(_ response: ScreeningModels.StartScreening.Response) async
    func presentPrepareStage(_ response: ScreeningModels.PrepareStage.Response) async
    func presentStartRecording(_ response: ScreeningModels.StartRecording.Response) async
    func presentSubmitAnswer(_ response: ScreeningModels.SubmitAnswer.Response) async
    func presentFinishScreening(_ response: ScreeningModels.FinishScreening.Response) async
    func presentRecordingError(_ error: ScreeningModels.RecordingError) async
    func presentMicrophonePermission(_ response: ScreeningModels.MicrophonePermission.Response) async
    func presentRescreeningCheck(_ response: ScreeningModels.CheckRescreening.Response) async
}

// MARK: - ScreeningPresenter

@MainActor
final class ScreeningPresenter: ScreeningPresentationLogic {

    weak var display: (any ScreeningDisplayLogic)?

    // MARK: - presentStartScreening

    func presentStartScreening(_ response: ScreeningModels.StartScreening.Response) async {
        let estMinutes = max(1, response.prompts.count / 2)
        let vm = ScreeningModels.StartScreening.ViewModel(
            prompts: response.prompts,
            progressText: String(localized: "screening.header.progress.\(response.prompts.count)"),
            estimatedMinutes: estMinutes,
            lyalyaPhrase: response.lyalyaPhrase
        )
        display?.displayStartScreening(vm)
    }

    // MARK: - presentPrepareStage

    func presentPrepareStage(_ response: ScreeningModels.PrepareStage.Response) async {
        let fraction = response.totalStages > 0
            ? Double(response.stageIndex + 1) / Double(response.totalStages)
            : 0
        let soundHint = String(localized: "screening.sound_hint.\(response.prompt.targetSound)")
        let vm = ScreeningModels.PrepareStage.ViewModel(
            stageIndex: response.stageIndex,
            totalStages: response.totalStages,
            progressFraction: fraction,
            targetWord: response.prompt.stimulus,
            targetSoundHint: soundHint,
            imageAsset: response.prompt.imageAsset,
            lyalyaPhrase: response.lyalyaPhrase,
            showRecordButton: response.canRecord
        )
        display?.displayPrepareStage(vm)
    }

    // MARK: - presentStartRecording

    func presentStartRecording(_ response: ScreeningModels.StartRecording.Response) async {
        let vm = ScreeningModels.StartRecording.ViewModel(
            stageIndex: response.stageIndex,
            isRecording: true,
            timerLabelText: String(localized: "screening.recording.listening")
        )
        display?.displayStartRecording(vm)
    }

    // MARK: - presentSubmitAnswer

    func presentSubmitAnswer(_ response: ScreeningModels.SubmitAnswer.Response) async {
        let adaptiveMessage: String? = response.adaptiveStopTriggered
            ? String(localized: "screening.adaptive_stop.message")
            : nil

        let vm = ScreeningModels.SubmitAnswer.ViewModel(
            nextPromptIndex: response.isScreeningComplete ? nil : response.currentPromptIndex + 1,
            shouldShowBlockTransition: response.isBlockComplete && !response.isScreeningComplete,
            shouldShowSummary: response.isScreeningComplete,
            adaptiveStopMessage: adaptiveMessage
        )
        display?.displaySubmitAnswer(vm)
    }

    // MARK: - presentFinishScreening

    func presentFinishScreening(_ response: ScreeningModels.FinishScreening.Response) async {
        let outcome = response.outcome
        let summary = summaryText(for: outcome)
        let verdicts = outcome.perSound
            .map { sound, verdict in
                SoundVerdictViewModel(
                    sound: sound,
                    verdict: verdict,
                    confidencePercent: confidencePercent(from: outcome, sound: sound),
                    exampleWord: nil
                )
            }
            .sorted { lhs, rhs in severityRank(lhs.verdict) > severityRank(rhs.verdict) }

        let testedLabel: String
        if response.wasAdaptiveStopped {
            testedLabel = String(
                localized: "screening.tested.adaptive.\(response.testedSoundsCount)"
            )
        } else {
            testedLabel = String(
                localized: "screening.tested.full.\(response.totalSoundsCount)"
            )
        }

        let vm = ScreeningModels.FinishScreening.ViewModel(
            outcomeSummary: summary,
            perSoundVerdicts: verdicts,
            recommendedSessionMinutes: outcome.recommendedSessionDurationSec / 60,
            priorityTargetSounds: outcome.priorityTargetSounds,
            wasAdaptiveStopped: response.wasAdaptiveStopped,
            testedLabel: testedLabel,
            lyalyaFinishPhrase: response.lyalyaFinishPhrase
        )
        display?.displayFinishScreening(vm)
    }

    // MARK: - presentRecordingError

    func presentRecordingError(_ error: ScreeningModels.RecordingError) async {
        display?.displayRecordingError(error)
    }

    // MARK: - presentMicrophonePermission

    func presentMicrophonePermission(_ response: ScreeningModels.MicrophonePermission.Response) async {
        let denied = response.isGranted
            ? nil
            : String(localized: "screening.mic.denied.message")
        let vm = ScreeningModels.MicrophonePermission.ViewModel(
            isGranted: response.isGranted,
            deniedMessage: denied
        )
        display?.displayMicrophonePermission(vm)
    }

    // MARK: - presentRescreeningCheck

    func presentRescreeningCheck(_ response: ScreeningModels.CheckRescreening.Response) async {
        let warning: String?
        if !response.isEligible, let days = response.daysSinceLastScreening {
            warning = String(localized: "screening.rescreening.too_soon.\(days)")
        } else {
            warning = nil
        }

        let previousSummary: String?
        if let prev = response.previousOutcomeSummary {
            let soundsList = prev.problematicSounds.isEmpty
                ? String(localized: "screening.rescreening.no_problems")
                : prev.problematicSounds.joined(separator: ", ")
            previousSummary = String(localized: "screening.rescreening.previous.\(soundsList)")
        } else {
            previousSummary = nil
        }

        let vm = ScreeningModels.CheckRescreening.ViewModel(
            isEligible: response.isEligible,
            warningMessage: warning,
            previousSummaryText: previousSummary
        )
        display?.displayRescreeningCheck(vm)
    }

    // MARK: - Private helpers

    private func summaryText(for outcome: ScreeningOutcome) -> String {
        if outcome.priorityTargetSounds.isEmpty {
            return String(localized: "screening.summary.all_normal")
        }
        let list = outcome.priorityTargetSounds.joined(separator: ", ")
        return String(localized: "screening.summary.intervention.\(list)")
    }

    private func severityRank(_ verdict: SoundVerdict) -> Int {
        switch verdict {
        case .normal:       return 0
        case .monitor:      return 1
        case .intervention: return 2
        }
    }

    private func confidencePercent(from outcome: ScreeningOutcome, sound: String) -> Int {
        // Derive approximate confidence from initialStage — intervention in "isolated"
        // stage implies lower confidence than "syllable"
        if outcome.initialStagePerSound[sound] == "isolated" { return 25 }
        switch outcome.perSound[sound] {
        case .normal:       return 90
        case .monitor:      return 65
        case .intervention: return 35
        case .none:         return 50
        }
    }
}
