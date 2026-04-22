import Foundation

// MARK: - OfflineStatePresentationLogic

@MainActor
protocol OfflineStatePresentationLogic: AnyObject {
    func presentFetch(_ response: OfflineStateModels.Fetch.Response)
    func presentUpdate(_ response: OfflineStateModels.Update.Response)
}

// MARK: - OfflineStatePresenter

@MainActor
final class OfflineStatePresenter: OfflineStatePresentationLogic {

    weak var viewModel: (any OfflineStateDisplayLogic)?

    func presentFetch(_ response: OfflineStateModels.Fetch.Response) {
        let vm = OfflineStateModels.Fetch.ViewModel()
        viewModel?.displayFetch(vm)
    }

    func presentUpdate(_ response: OfflineStateModels.Update.Response) {
        let vm = OfflineStateModels.Update.ViewModel()
        viewModel?.displayUpdate(vm)
    }
}
