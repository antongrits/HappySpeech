import Foundation

// MARK: - OfflineStateDisplayLogic

@MainActor
protocol OfflineStateDisplayLogic: AnyObject {
    func displayFetch(_ viewModel: OfflineStateModels.Fetch.ViewModel)
    func displayUpdate(_ viewModel: OfflineStateModels.Update.ViewModel)
}
