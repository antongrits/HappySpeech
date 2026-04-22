import Foundation

// MARK: - RewardsPresentationLogic

@MainActor
protocol RewardsPresentationLogic: AnyObject {
    func presentFetch(_ response: RewardsModels.Fetch.Response)
    func presentUpdate(_ response: RewardsModels.Update.Response)
}

// MARK: - RewardsPresenter

@MainActor
final class RewardsPresenter: RewardsPresentationLogic {

    weak var viewModel: (any RewardsDisplayLogic)?

    func presentFetch(_ response: RewardsModels.Fetch.Response) {
        let vm = RewardsModels.Fetch.ViewModel()
        viewModel?.displayFetch(vm)
    }

    func presentUpdate(_ response: RewardsModels.Update.Response) {
        let vm = RewardsModels.Update.ViewModel()
        viewModel?.displayUpdate(vm)
    }
}
