import Foundation

// MARK: - SessionCompletePresentationLogic

@MainActor
protocol SessionCompletePresentationLogic: AnyObject {
    func presentFetch(_ response: SessionCompleteModels.Fetch.Response)
    func presentUpdate(_ response: SessionCompleteModels.Update.Response)
}

// MARK: - SessionCompletePresenter

@MainActor
final class SessionCompletePresenter: SessionCompletePresentationLogic {

    weak var viewModel: (any SessionCompleteDisplayLogic)?

    func presentFetch(_ response: SessionCompleteModels.Fetch.Response) {
        let vm = SessionCompleteModels.Fetch.ViewModel()
        viewModel?.displayFetch(vm)
    }

    func presentUpdate(_ response: SessionCompleteModels.Update.Response) {
        let vm = SessionCompleteModels.Update.ViewModel()
        viewModel?.displayUpdate(vm)
    }
}
