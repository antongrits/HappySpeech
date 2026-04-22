import Foundation

// MARK: - SessionHistoryPresentationLogic

@MainActor
protocol SessionHistoryPresentationLogic: AnyObject {
    func presentFetch(_ response: SessionHistoryModels.Fetch.Response)
    func presentUpdate(_ response: SessionHistoryModels.Update.Response)
}

// MARK: - SessionHistoryPresenter

@MainActor
final class SessionHistoryPresenter: SessionHistoryPresentationLogic {

    weak var viewModel: (any SessionHistoryDisplayLogic)?

    func presentFetch(_ response: SessionHistoryModels.Fetch.Response) {
        let vm = SessionHistoryModels.Fetch.ViewModel()
        viewModel?.displayFetch(vm)
    }

    func presentUpdate(_ response: SessionHistoryModels.Update.Response) {
        let vm = SessionHistoryModels.Update.ViewModel()
        viewModel?.displayUpdate(vm)
    }
}
