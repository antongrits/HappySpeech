import Foundation

// MARK: - NarrativeQuestPresentationLogic

@MainActor
protocol NarrativeQuestPresentationLogic: AnyObject {
    func presentLoadQuest(_ response: NarrativeQuestModels.LoadQuest.Response)
    func presentStartStage(_ response: NarrativeQuestModels.StartStage.Response)
    func presentRecordWord(_ response: NarrativeQuestModels.RecordWord.Response)
    func presentEvaluateWord(_ response: NarrativeQuestModels.EvaluateWord.Response)
    func presentAdvanceStage(_ response: NarrativeQuestModels.AdvanceStage.Response)
    func presentCompleteQuest(_ response: NarrativeQuestModels.CompleteQuest.Response)
}

// MARK: - NarrativeQuestPresenter

/// Формирует ViewModel из response интерактора и передаёт в `displayLogic`.
/// Никакой бизнес-логики — только форматирование, локализация и простые
/// производные (звёзды, подписи прогресса).
@MainActor
final class NarrativeQuestPresenter: NarrativeQuestPresentationLogic {

    weak var displayLogic: (any NarrativeQuestDisplayLogic)?

    // MARK: - LoadQuest

    func presentLoadQuest(_ response: NarrativeQuestModels.LoadQuest.Response) {
        let vm = NarrativeQuestModels.LoadQuest.ViewModel(
            questTitle: response.script.title,
            totalStages: response.script.stages.count,
            finalRewardEmoji: response.script.finalRewardEmoji,
            introNarration: response.script.introNarration
        )
        displayLogic?.displayLoadQuest(vm)
    }

    // MARK: - StartStage

    func presentStartStage(_ response: NarrativeQuestModels.StartStage.Response) {
        let vm = NarrativeQuestModels.StartStage.ViewModel(
            narration: response.stage.narration,
            task: response.stage.task,
            targetWord: response.stage.targetWord,
            hint: response.stage.hint,
            rewardEmoji: response.stage.rewardEmoji,
            stageNumber: response.stageNumber,
            totalStages: response.totalStages,
            progressFraction: response.progressFraction
        )
        displayLogic?.displayStartStage(vm)
    }

    // MARK: - RecordWord

    func presentRecordWord(_ response: NarrativeQuestModels.RecordWord.Response) {
        let micLabel = response.isListening
            ? String(localized: "Говори!")
            : String(localized: "Нажми, чтобы записать")
        let vm = NarrativeQuestModels.RecordWord.ViewModel(
            isListening: response.isListening,
            micLabel: micLabel
        )
        displayLogic?.displayRecordWord(vm)
    }

    // MARK: - EvaluateWord

    func presentEvaluateWord(_ response: NarrativeQuestModels.EvaluateWord.Response) {
        let feedback: String
        if response.passed {
            feedback = response.successNarration.isEmpty
                ? String(localized: "Отлично! Ляля гордится тобой.")
                : response.successNarration
        } else {
            feedback = String(localized: "Почти получилось! Пробуем дальше.")
        }

        let vm = NarrativeQuestModels.EvaluateWord.ViewModel(
            feedbackText: feedback,
            feedbackSuccess: response.passed,
            rewardEmoji: response.rewardEmoji,
            showSuccessOverlay: response.passed,
            score: response.score
        )
        displayLogic?.displayEvaluateWord(vm)
    }

    // MARK: - AdvanceStage

    func presentAdvanceStage(_ response: NarrativeQuestModels.AdvanceStage.Response) {
        let isLast = response.nextStageIndex == nil
        let vm = NarrativeQuestModels.AdvanceStage.ViewModel(
            collectedEmojis: response.collectedEmojis,
            progressFraction: response.progressFraction,
            stageNumber: response.stageNumber,
            isLast: isLast
        )
        displayLogic?.displayAdvanceStage(vm)
    }

    // MARK: - CompleteQuest

    func presentCompleteQuest(_ response: NarrativeQuestModels.CompleteQuest.Response) {
        let scoreLabel = String(
            format: String(localized: "Твой результат: %d%%"),
            Int((response.averageScore * 100).rounded())
        )
        let vm = NarrativeQuestModels.CompleteQuest.ViewModel(
            starsEarned: response.starsEarned,
            collectedEmojis: response.collectedEmojis,
            finalRewardEmoji: response.finalRewardEmoji,
            completionMessage: response.finalMessage,
            scoreLabel: scoreLabel,
            normalizedScore: max(0, min(1, response.averageScore))
        )
        displayLogic?.displayCompleteQuest(vm)
    }

    // MARK: - Scoring

    /// Правило звёзд: ≥0.9 → 3, ≥0.7 → 2, ≥0.5 → 1, иначе 0.
    static func stars(for score: Float) -> Int {
        switch score {
        case 0.9...:        return 3
        case 0.7..<0.9:     return 2
        case 0.5..<0.7:     return 1
        default:            return 0
        }
    }
}
