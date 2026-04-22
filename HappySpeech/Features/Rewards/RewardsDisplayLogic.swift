import Foundation

// MARK: - RewardsDisplayLogic

@MainActor
protocol RewardsDisplayLogic: AnyObject {
    func displayFetch(_ viewModel: RewardsModels.Fetch.ViewModel)
    func displayUpdate(_ viewModel: RewardsModels.Update.ViewModel)
}
