import Foundation

// MARK: - AuthDisplayLogic

@MainActor
protocol AuthDisplayLogic: AnyObject {
    func displayFetch(_ viewModel: AuthModels.Fetch.ViewModel)
    func displayUpdate(_ viewModel: AuthModels.Update.ViewModel)
}
