import Foundation

// MARK: - ListenAndChoosePresentationLogic

@MainActor
protocol ListenAndChoosePresentationLogic: AnyObject {
    func presentLoadSession(_ response: ListenAndChooseModels.LoadSession.Response)
    func presentSubmitAttempt(_ response: ListenAndChooseModels.SubmitAttempt.Response)
}

// MARK: - ListenAndChoosePresenter

@MainActor
final class ListenAndChoosePresenter: ListenAndChoosePresentationLogic {

    weak var viewModel: (any ListenAndChooseDisplayLogic)?

    func presentLoadSession(_ response: ListenAndChooseModels.LoadSession.Response) {
        let vm = ListenAndChooseModels.LoadSession.ViewModel(displayItems: response.items)
        viewModel?.displayLoadSession(vm)
    }

    func presentSubmitAttempt(_ response: ListenAndChooseModels.SubmitAttempt.Response) {
        let feedbackText = response.isCorrect ? "Отлично!" : "Попробуй ещё раз"
        let vm = ListenAndChooseModels.SubmitAttempt.ViewModel(
            feedbackText: feedbackText,
            isCorrect: response.isCorrect
        )
        viewModel?.displaySubmitAttempt(vm)
    }
}
