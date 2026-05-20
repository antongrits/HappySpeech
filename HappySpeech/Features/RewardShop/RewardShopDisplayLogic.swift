import Foundation

// MARK: - RewardShopDisplayLogic

@MainActor
protocol RewardShopDisplayLogic: AnyObject {
    func displayLoad(viewModel: RewardShopModels.Load.ViewModel) async
    func displayPurchaseSuccess(viewModel: RewardShopModels.Purchase.ViewModel) async
    func displayPurchaseFailure(viewModel: RewardShopModels.Purchase.FailureViewModel) async
}

// MARK: - RewardShopPresentationLogic

@MainActor
protocol RewardShopPresentationLogic: AnyObject {
    func presentLoad(response: RewardShopModels.Load.Response) async
    func presentPurchaseSuccess(response: RewardShopModels.Purchase.Response) async
    func presentPurchaseFailure(response: RewardShopModels.Purchase.FailureResponse) async
}
