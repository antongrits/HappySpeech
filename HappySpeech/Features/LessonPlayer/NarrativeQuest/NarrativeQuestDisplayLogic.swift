import Foundation

// MARK: - NarrativeQuestDisplayLogic

@MainActor
protocol NarrativeQuestDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: NarrativeQuestModels.LoadSession.ViewModel)
    func displaySubmitAttempt(_ viewModel: NarrativeQuestModels.SubmitAttempt.ViewModel)
}
