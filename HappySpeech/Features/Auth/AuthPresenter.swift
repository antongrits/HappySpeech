import Foundation

// MARK: - AuthPresentationLogic

@MainActor
protocol AuthPresentationLogic: AnyObject {
    func presentFetch(_ response: AuthModels.Fetch.Response)
    func presentUpdate(_ response: AuthModels.Update.Response)
}

// MARK: - AuthPresenter

@MainActor
final class AuthPresenter: AuthPresentationLogic {

    weak var viewModel: (any AuthDisplayLogic)?

    func presentFetch(_ response: AuthModels.Fetch.Response) {
        let vm = AuthModels.Fetch.ViewModel()
        viewModel?.displayFetch(vm)
    }

    func presentUpdate(_ response: AuthModels.Update.Response) {
        let vm = AuthModels.Update.ViewModel()
        viewModel?.displayUpdate(vm)
    }
}
