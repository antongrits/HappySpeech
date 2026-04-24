import Foundation

// MARK: - NarrativeQuestDisplayLogic
//
// Протокол, которым презентер обновляет @Observable store
// (`NarrativeQuestDisplay`) через тонкий bridge. Каждый метод
// соответствует одному VIP-usecase.

@MainActor
protocol NarrativeQuestDisplayLogic: AnyObject {
    func displayLoadQuest(_ viewModel: NarrativeQuestModels.LoadQuest.ViewModel)
    func displayStartStage(_ viewModel: NarrativeQuestModels.StartStage.ViewModel)
    func displayRecordWord(_ viewModel: NarrativeQuestModels.RecordWord.ViewModel)
    func displayEvaluateWord(_ viewModel: NarrativeQuestModels.EvaluateWord.ViewModel)
    func displayAdvanceStage(_ viewModel: NarrativeQuestModels.AdvanceStage.ViewModel)
    func displayCompleteQuest(_ viewModel: NarrativeQuestModels.CompleteQuest.ViewModel)
}

// MARK: - Default handshake extension
//
// View подписывается на `NarrativeQuestDisplay.pendingFinalScore`
// через `onChange`. Default-реализация не нужна — все обновления
// явно делаются StoreBridge в `NarrativeQuestView.swift`.

extension NarrativeQuestDisplayLogic {
    /// Преобразует скор в безопасный диапазон [0; 1] для UI-контроля.
    func normalized(_ score: Float) -> Float {
        max(0, min(1, score))
    }
}
