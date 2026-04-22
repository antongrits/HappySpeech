import Foundation

// MARK: - PermissionsPresentationLogic

@MainActor
protocol PermissionsPresentationLogic: AnyObject {
    func presentFetch(_ response: PermissionsModels.Fetch.Response)
    func presentUpdate(_ response: PermissionsModels.Update.Response)
}

// MARK: - PermissionsPresenter

@MainActor
final class PermissionsPresenter: PermissionsPresentationLogic {

    weak var viewModel: (any PermissionsDisplayLogic)?

    func presentFetch(_ response: PermissionsModels.Fetch.Response) {
        let vm = PermissionsModels.Fetch.ViewModel()
        viewModel?.displayFetch(vm)
    }

    func presentUpdate(_ response: PermissionsModels.Update.Response) {
        let vm = PermissionsModels.Update.ViewModel()
        viewModel?.displayUpdate(vm)
    }
}
