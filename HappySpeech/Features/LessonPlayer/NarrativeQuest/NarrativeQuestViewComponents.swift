import OSLog
import SwiftUI

// MARK: - NarrativeQuestViewComponents
//
// Подкомпоненты narrative-quest: store-bridge и Preview. Извлечено из
// `NarrativeQuestView.swift` (Block K.8 v16) для удержания LOC ≤700.

// MARK: - StoreBridge

/// Тонкий bridge между презентером и `@Observable` store.
/// Обновляет свойства стора в главном потоке — View автоматически
/// реагирует через Observation framework.
@MainActor
final class NarrativeQuestStoreBridge: NarrativeQuestDisplayLogic {

    private let display: NarrativeQuestDisplay

    init(display: NarrativeQuestDisplay) {
        self.display = display
    }

    func displayLoadQuest(_ viewModel: NarrativeQuestModels.LoadQuest.ViewModel) {
        display.questTitle = viewModel.questTitle
        display.totalStages = viewModel.totalStages
        display.finalRewardEmoji = viewModel.finalRewardEmoji
        display.introNarration = viewModel.introNarration
        display.progressFraction = 0
        display.stageNumber = 0
        display.collectedEmojis = []
        display.phase = .questIntro
    }

    func displayStartStage(_ viewModel: NarrativeQuestModels.StartStage.ViewModel) {
        display.narration = viewModel.narration
        display.task = viewModel.task
        display.targetWord = viewModel.targetWord
        display.hint = viewModel.hint
        display.rewardEmoji = viewModel.rewardEmoji
        display.stageNumber = viewModel.stageNumber
        display.totalStages = viewModel.totalStages
        display.progressFraction = viewModel.progressFraction
        display.isListening = false
        display.showSuccessOverlay = false
        display.phase = .stageNarration
    }

    func displayRecordWord(_ viewModel: NarrativeQuestModels.RecordWord.ViewModel) {
        display.isListening = viewModel.isListening
        display.micLabel = viewModel.micLabel
        if viewModel.isListening {
            display.phase = .recording
        }
    }

    func displayEvaluateWord(_ viewModel: NarrativeQuestModels.EvaluateWord.ViewModel) {
        display.feedbackText = viewModel.feedbackText
        display.feedbackSuccess = viewModel.feedbackSuccess
        display.rewardEmoji = viewModel.rewardEmoji
        display.showSuccessOverlay = viewModel.showSuccessOverlay
        display.lastScore = viewModel.score
        display.phase = .stageFeedback
    }

    func displayAdvanceStage(_ viewModel: NarrativeQuestModels.AdvanceStage.ViewModel) {
        display.collectedEmojis = viewModel.collectedEmojis
        display.progressFraction = viewModel.progressFraction
        display.stageNumber = viewModel.stageNumber
        // Фаза меняется в startStage/completeQuest — здесь только накопление.
    }

    func displayCompleteQuest(_ viewModel: NarrativeQuestModels.CompleteQuest.ViewModel) {
        display.starsEarned = viewModel.starsEarned
        display.collectedEmojis = viewModel.collectedEmojis
        display.finalRewardEmoji = viewModel.finalRewardEmoji
        display.completionMessage = viewModel.completionMessage
        display.scoreLabel = viewModel.scoreLabel
        display.lastScore = viewModel.normalizedScore
        display.progressFraction = 1.0
        display.showSuccessOverlay = false
        display.phase = .questComplete
        display.pendingFinalScore = viewModel.normalizedScore
    }
}

// MARK: - Preview

#Preview {
    NarrativeQuestView(
        activity: SessionActivity(
            id: "preview",
            gameType: .narrativeQuest,
            lessonId: "l1",
            soundTarget: "С",
            difficulty: 1,
            isCompleted: false,
            score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
