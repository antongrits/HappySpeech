import Foundation
import OSLog

// MARK: - RewardShopPresenter (Clean Swift: Presenter)

@MainActor
final class RewardShopPresenter: RewardShopPresentationLogic {

    private weak var displayLogic: (any RewardShopDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "RewardShop.Presenter"
    )

    init(displayLogic: any RewardShopDisplayLogic) {
        self.displayLogic = displayLogic
    }

    func presentLoad(response: RewardShopModels.Load.Response) async {
        let balance = max(0, response.coinsEarned - response.coinsSpent)
        let balanceText = String(
            format: String(localized: "rewardShop.balance.text"),
            balance
        )
        let earnedText = String(
            format: String(localized: "rewardShop.earned.text"),
            response.coinsEarned
        )
        let spentText = String(
            format: String(localized: "rewardShop.spent.text"),
            response.coinsSpent
        )

        let grouped = Dictionary(grouping: response.catalog, by: \.category)
        let orderedCategories = StickerCategory.allCases.compactMap { category -> RewardShopModels.Load.CategoryViewModel? in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            let sorted = items.sorted { $0.price < $1.price }
            let stickers = sorted.map { item in
                let isOwned = response.ownedStickerIds.contains(item.id)
                let isAffordable = balance >= item.price
                let priceText = String(
                    format: String(localized: "rewardShop.sticker.price"),
                    item.price
                )
                let label = stickerAccessibilityLabel(
                    name: item.name,
                    price: item.price,
                    isOwned: isOwned,
                    isAffordable: isAffordable
                )
                return RewardShopModels.Load.StickerViewModel(
                    id: item.id,
                    name: item.name,
                    price: item.price,
                    priceText: priceText,
                    imageName: item.imageName,
                    isOwned: isOwned,
                    isAffordable: isAffordable,
                    rarity: item.rarity,
                    accessibilityLabel: label
                )
            }
            return RewardShopModels.Load.CategoryViewModel(
                id: category.rawValue,
                titleKey: category.titleKey,
                stickers: stickers
            )
        }

        let viewModel = RewardShopModels.Load.ViewModel(
            coinsBalance: balance,
            coinsBalanceText: balanceText,
            totalEarnedText: earnedText,
            totalSpentText: spentText,
            categories: orderedCategories
        )
        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    func presentPurchaseSuccess(response: RewardShopModels.Purchase.Response) async {
        let title = String(localized: "rewardShop.toast.success.title")
        let message = String(
            format: String(localized: "rewardShop.toast.success.message"),
            response.stickerName,
            response.newBalance
        )
        await displayLogic?.displayPurchaseSuccess(
            viewModel: .init(toastTitle: title, toastMessage: message)
        )
    }

    func presentPurchaseFailure(response: RewardShopModels.Purchase.FailureResponse) async {
        let title = String(localized: "rewardShop.toast.error.title")
        let message: String
        switch response.reason {
        case .unknownSticker:
            message = String(localized: "rewardShop.toast.error.unknown")
        case .alreadyOwned:
            message = String(localized: "rewardShop.toast.error.owned")
        case .notEnoughCoins(let have, let need):
            message = String(
                format: String(localized: "rewardShop.toast.error.coins"),
                need - have
            )
        }
        await displayLogic?.displayPurchaseFailure(
            viewModel: .init(toastTitle: title, toastMessage: message)
        )
    }

    // MARK: - Helpers

    private func stickerAccessibilityLabel(
        name: String,
        price: Int,
        isOwned: Bool,
        isAffordable: Bool
    ) -> String {
        if isOwned {
            return String(format: String(localized: "rewardShop.a11y.owned"), name)
        }
        if !isAffordable {
            return String(format: String(localized: "rewardShop.a11y.locked"), name, price)
        }
        return String(format: String(localized: "rewardShop.a11y.affordable"), name, price)
    }
}
