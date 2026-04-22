import Foundation

// MARK: - NarrativeQuestPresentationLogic

@MainActor
protocol NarrativeQuestPresentationLogic: AnyObject {
    func presentLoadSession(_ response: NarrativeQuestModels.LoadSession.Response)
    func presentSubmitAttempt(_ response: NarrativeQuestModels.SubmitAttempt.Response)
}

// MARK: - NarrativeQuestPresenter

@MainActor
final class NarrativeQuestPresenter: NarrativeQuestPresentationLogic {

    weak var viewModel: (any NarrativeQuestDisplayLogic)?

    func presentLoadSession(_ response: NarrativeQuestModels.LoadSession.Response) {
        let vm = NarrativeQuestModels.LoadSession.ViewModel(displayItems: response.items)
        viewModel?.displayLoadSession(vm)
    }

    func presentSubmitAttempt(_ response: NarrativeQuestModels.SubmitAttempt.Response) {
        let feedbackText = response.isCorrect ? "Отлично!" : "Попробуй ещё раз"
        let vm = NarrativeQuestModels.SubmitAttempt.ViewModel(
            feedbackText: feedbackText,
            isCorrect: response.isCorrect
        )
        viewModel?.displaySubmitAttempt(vm)
    }
}
