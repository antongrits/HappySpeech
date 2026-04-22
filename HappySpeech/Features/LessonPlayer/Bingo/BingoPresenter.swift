import Foundation

// MARK: - BingoPresentationLogic

@MainActor
protocol BingoPresentationLogic: AnyObject {
    func presentLoadSession(_ response: BingoModels.LoadSession.Response)
    func presentSubmitAttempt(_ response: BingoModels.SubmitAttempt.Response)
}

// MARK: - BingoPresenter

@MainActor
final class BingoPresenter: BingoPresentationLogic {

    weak var viewModel: (any BingoDisplayLogic)?

    func presentLoadSession(_ response: BingoModels.LoadSession.Response) {
        let vm = BingoModels.LoadSession.ViewModel(displayItems: response.items)
        viewModel?.displayLoadSession(vm)
    }

    func presentSubmitAttempt(_ response: BingoModels.SubmitAttempt.Response) {
        let feedbackText = response.isCorrect ? "Отлично!" : "Попробуй ещё раз"
        let vm = BingoModels.SubmitAttempt.ViewModel(
            feedbackText: feedbackText,
            isCorrect: response.isCorrect
        )
        viewModel?.displaySubmitAttempt(vm)
    }
}
