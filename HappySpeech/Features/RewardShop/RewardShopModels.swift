import Foundation

// MARK: - RewardShopModels (Clean Swift: Models)
//
// v31 Волна C, Функция Ф.1 «Магазин наград».
//
// Дети тратят заработанные монеты (1 RewardRecord ≈ 1 монета) на стикеры.
// Стикеры — бессмысленные «фантики», NO real-money IAP. Все ресурсы
// локальные, никаких внешних трекеров (project guide §11).

// MARK: - ShopStickerRarity

public enum ShopStickerRarity: String, Sendable, Codable, Equatable {
    case common
    case uncommon
    case rare
    case epic
    case legendary
}

// MARK: - StickerCategory

public enum StickerCategory: String, Sendable, Codable, Equatable, CaseIterable {
    case achievement
    case animal
    case lyalya
    case phoneme
    case seasonal

    public var titleKey: String {
        switch self {
        case .achievement: return "rewardShop.category.achievement"
        case .animal:      return "rewardShop.category.animal"
        case .lyalya:      return "rewardShop.category.lyalya"
        case .phoneme:     return "rewardShop.category.phoneme"
        case .seasonal:    return "rewardShop.category.seasonal"
        }
    }
}

// MARK: - StickerItem (catalog entry)

public struct StickerItem: Sendable, Identifiable, Equatable, Codable {
    public let id: String
    public let name: String
    public let price: Int
    public let category: StickerCategory
    public let imageName: String
    public let rarity: ShopStickerRarity

    public init(
        id: String,
        name: String,
        price: Int,
        category: StickerCategory,
        imageName: String,
        rarity: ShopStickerRarity
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.category = category
        self.imageName = imageName
        self.rarity = rarity
    }
}

// MARK: - PurchaseError

public enum PurchaseError: Error, Equatable, Sendable {
    case unknownSticker
    case alreadyOwned
    case notEnoughCoins(have: Int, need: Int)
}

// MARK: - RewardShopModels namespace

enum RewardShopModels {

    // MARK: Load

    enum Load {
        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let coinsEarned: Int
            let coinsSpent: Int
            let ownedStickerIds: Set<String>
            let catalog: [StickerItem]
        }

        struct ViewModel: Sendable {
            let coinsBalance: Int
            let coinsBalanceText: String
            let totalEarnedText: String
            let totalSpentText: String
            let categories: [CategoryViewModel]
        }

        struct CategoryViewModel: Sendable, Identifiable {
            let id: String
            let titleKey: String
            let stickers: [StickerViewModel]
        }

        struct StickerViewModel: Sendable, Identifiable, Equatable {
            let id: String
            let name: String
            let price: Int
            let priceText: String
            let imageName: String
            let isOwned: Bool
            let isAffordable: Bool
            let rarity: ShopStickerRarity
            let accessibilityLabel: String
        }
    }

    // MARK: Purchase

    enum Purchase {
        struct Request: Sendable {
            let childId: String
            let stickerId: String
        }

        struct Response: Sendable {
            let stickerId: String
            let stickerName: String
            let newBalance: Int
        }

        struct FailureResponse: Sendable {
            let stickerId: String
            let reason: PurchaseError
        }

        struct ViewModel: Sendable {
            let toastTitle: String
            let toastMessage: String
        }

        struct FailureViewModel: Sendable {
            let toastTitle: String
            let toastMessage: String
        }
    }
}
