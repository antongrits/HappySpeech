import Foundation

// MARK: - OralStoryCreatorPresenter

@MainActor
final class OralStoryCreatorPresenter {

    weak var displayLogic: (any OralStoryCreatorDisplayLogic)?

    init(displayLogic: any OralStoryCreatorDisplayLogic) {
        self.displayLogic = displayLogic
    }

    // MARK: - Load Stimuli

    func presentLoadStimuli(response: OralStoryCreatorModels.LoadStimuli.Response) async {
        var grouped: [String: [StimulusPicture]] = [:]
        for stimulus in response.stimuli {
            grouped[stimulus.category, default: []].append(stimulus)
        }
        let viewModel = OralStoryCreatorModels.LoadStimuli.ViewModel(
            grouped: grouped,
            categoriesInOrder: OralStoryCreatorCorpus.categoriesInOrder,
            pickCountTarget: OralStoryCreatorCorpus.pickCountTarget
        )
        await displayLogic?.displayLoadStimuli(viewModel: viewModel)
    }

    // MARK: - Selection

    func presentSelection(response: OralStoryCreatorModels.Select.Response) async {
        let target = OralStoryCreatorCorpus.pickCountTarget
        let count = response.selectedIds.count
        let canStart = count == target
        let status: String
        if count == 0 {
            status = "Выбери \(target) картинки для истории."
        } else if count < target {
            let remaining = target - count
            status = "Осталось выбрать: \(remaining)."
        } else {
            status = "Готов! Нажми «Записать»."
        }
        let viewModel = OralStoryCreatorModels.Select.ViewModel(
            selectedIds: response.selectedIds,
            canStartRecording: canStart,
            statusMessage: status
        )
        await displayLogic?.displaySelect(viewModel: viewModel)
    }

    // MARK: - Record Result

    func presentRecordResult(response: OralStoryCreatorModels.RecordResult.Response) async {
        let calculator = LexicalDiversityCalculator()
        let (total, unique, ttr) = calculator.analyse(transcript: response.transcript)
        let durationLabel = formatDuration(response.durationSeconds)
        let percent = Int((ttr * 100).rounded())
        let viewModel = OralStoryCreatorModels.RecordResult.ViewModel(
            transcript: response.transcript,
            durationLabel: durationLabel,
            totalWords: total,
            uniqueWords: unique,
            lexicalDiversity: ttr,
            lexicalDiversityPercent: percent,
            stimuli: response.stimuli,
            savedStoryId: response.savedStoryId,
            accessibilityLabel: "История из \(total) слов. Уникальных: \(unique). Разнообразие: \(percent)%."
        )
        await displayLogic?.displayRecordResult(viewModel: viewModel)
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
