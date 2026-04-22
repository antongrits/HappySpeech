import Foundation

// MARK: - PermissionsDisplayLogic

@MainActor
protocol PermissionsDisplayLogic: AnyObject {
    func displayFetch(_ viewModel: PermissionsModels.Fetch.ViewModel)
    func displayUpdate(_ viewModel: PermissionsModels.Update.ViewModel)
}
