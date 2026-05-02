import Foundation
import SwiftUI

// MARK: - Rewards VIP Models
//
// Экран альбома стикеров и достижений (kid-контур).
// Поддерживает: 6 коллекций, 72 стикера, 32 достижения, редкость (rarity),
// тему альбома, кошелёк звёзд, фильтр/сортировку, streak-rewards, шаринг.

// MARK: - StickerRarity

public enum StickerRarity: String, Sendable, CaseIterable, Comparable {
    case common
    case rare
    case epic
    case legendary

    public static func < (lhs: StickerRarity, rhs: StickerRarity) -> Bool {
        let order: [StickerRarity] = [.common, .rare, .epic, .legendary]
        guard let li = order.firstIndex(of: lhs), let ri = order.firstIndex(of: rhs) else { return false }
        return li < ri
    }

    public var displayName: String {
        switch self {
        case .common:    return String(localized: "rewards.rarity.common")
        case .rare:      return String(localized: "rewards.rarity.rare")
        case .epic:      return String(localized: "rewards.rarity.epic")
        case .legendary: return String(localized: "rewards.rarity.legendary")
        }
    }

    public var borderColor: Color {
        switch self {
        case .common:    return ColorTokens.Kid.line
        case .rare:      return ColorTokens.Brand.sky
        case .epic:      return ColorTokens.Brand.lilac
        case .legendary: return ColorTokens.Brand.gold
        }
    }

    public var dropWeight: Double {
        switch self {
        case .common:    return 0.50
        case .rare:      return 0.30
        case .epic:      return 0.15
        case .legendary: return 0.05
        }
    }

    public var starCost: Int {
        switch self {
        case .common:    return 0
        case .rare:      return 5
        case .epic:      return 15
        case .legendary: return 40
        }
    }
}

// MARK: - StickerCollection

public enum StickerCollection: String, Sendable, CaseIterable, Identifiable {
    case all
    case animals
    case space
    case forest
    case ocean
    case halloween
    case newYear

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .all:       return String(localized: "rewards.collection.all")
        case .animals:   return String(localized: "rewards.collection.animals")
        case .space:     return String(localized: "rewards.collection.space")
        case .forest:    return String(localized: "rewards.collection.forest")
        case .ocean:     return String(localized: "rewards.collection.ocean")
        case .halloween: return String(localized: "rewards.collection.halloween")
        case .newYear:   return String(localized: "rewards.collection.newYear")
        }
    }

    public var emoji: String {
        switch self {
        case .all:       return "🎁"
        case .animals:   return "🐾"
        case .space:     return "🚀"
        case .forest:    return "🌲"
        case .ocean:     return "🌊"
        case .halloween: return "🎃"
        case .newYear:   return "🎆"
        }
    }

    public var totalSlots: Int {
        switch self {
        case .all:       return 0
        case .animals:   return 12
        case .space:     return 12
        case .forest:    return 12
        case .ocean:     return 12
        case .halloween: return 12
        case .newYear:   return 12
        }
    }
}

// MARK: - AlbumTheme

public enum AlbumTheme: String, Sendable, CaseIterable, Identifiable {
    case bright
    case dark
    case pastel
    case neon

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .bright: return String(localized: "rewards.theme.bright")
        case .dark:   return String(localized: "rewards.theme.dark")
        case .pastel: return String(localized: "rewards.theme.pastel")
        case .neon:   return String(localized: "rewards.theme.neon")
        }
    }

    public var previewEmoji: String {
        switch self {
        case .bright: return "☀️"
        case .dark:   return "🌙"
        case .pastel: return "🌸"
        case .neon:   return "💡"
        }
    }

    public var backgroundColor: Color {
        switch self {
        case .bright: return ColorTokens.Kid.bg
        case .dark:   return Color("ThemeDarkBg")
        case .pastel: return Color("ThemePastelBg")
        case .neon:   return Color("ThemeNeonBg")
        }
    }
}

// MARK: - SortOrder

public enum RewardsSortOrder: String, Sendable, CaseIterable {
    case byCollection = "collection"
    case byDate       = "date"
    case byRarity     = "rarity"

    public var displayName: String {
        switch self {
        case .byCollection: return String(localized: "rewards.sort.collection")
        case .byDate:       return String(localized: "rewards.sort.date")
        case .byRarity:     return String(localized: "rewards.sort.rarity")
        }
    }
}

// MARK: - Sticker (DTO)

public struct Sticker: Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public let emoji: String
    public let name: String
    public let collection: StickerCollection
    public let rarity: StickerRarity
    public let linkedSoundId: String?
    public var isUnlocked: Bool
    public var isNew: Bool
    public let unlockCondition: String
    public let unlockedAt: Date?

    public init(
        id: String,
        emoji: String,
        name: String,
        collection: StickerCollection,
        rarity: StickerRarity = .common,
        linkedSoundId: String? = nil,
        isUnlocked: Bool,
        isNew: Bool,
        unlockCondition: String,
        unlockedAt: Date?
    ) {
        self.id = id
        self.emoji = emoji
        self.name = name
        self.collection = collection
        self.rarity = rarity
        self.linkedSoundId = linkedSoundId
        self.isUnlocked = isUnlocked
        self.isNew = isNew
        self.unlockCondition = unlockCondition
        self.unlockedAt = unlockedAt
    }
}

// MARK: - RewardsAchievement

public struct RewardsAchievement: Sendable, Identifiable, Equatable {
    public enum Medal: String, Sendable {
        case bronze
        case silver
        case gold
    }

    public let id: String
    public let key: String
    public let emoji: String
    public let title: String
    public let hint: String
    public let medal: Medal
    public let requiredProgress: Int
    public var currentProgress: Int
    public var isUnlocked: Bool
    public var unlockedAt: Date?

    public var progressFraction: Double {
        guard requiredProgress > 0 else { return isUnlocked ? 1 : 0 }
        return min(Double(currentProgress) / Double(requiredProgress), 1.0)
    }
}

// MARK: - StarsWallet

public struct StarsWallet: Sendable, Equatable {
    public var totalEarned: Int
    public var totalSpent: Int
    public var available: Int { totalEarned - totalSpent }

    public static let empty = StarsWallet(totalEarned: 0, totalSpent: 0)
}

// MARK: - StreakReward

public struct StreakReward: Sendable, Equatable {
    public let streakDays: Int
    public let rewardDescription: String
    public var isClaimed: Bool
}

// MARK: - VIP scenes

enum RewardsModels {

    // MARK: - LoadRewards

    enum LoadRewards {
        struct Request: Sendable {
            let childId: String
            let forceReload: Bool
        }
        struct Response: Sendable {
            let stickers: [Sticker]
            let achievements: [RewardsAchievement]
            let wallet: StarsWallet
            let activeCollection: StickerCollection
            let sortOrder: RewardsSortOrder
            let albumTheme: AlbumTheme
            let streakRewards: [StreakReward]
            let currentStreak: Int
        }
        struct ViewModel: Sendable {
            let cells: [StickerCellViewModel]
            let achievementRows: [AchievementRowViewModel]
            let collections: [CollectionTabViewModel]
            let unlockedCount: Int
            let totalCount: Int
            let progressLabel: String
            let progress: Double
            let isEmpty: Bool
            let emptyTitle: String
            let emptyMessage: String
            let activeCollection: StickerCollection
            let sortOrder: RewardsSortOrder
            let albumTheme: AlbumTheme
            let walletViewModel: StarsWalletViewModel
            let streakBanners: [StreakBannerViewModel]
            let currentStreak: Int
        }
    }

    // MARK: - FilterByCollection

    enum FilterByCollection {
        struct Request: Sendable {
            let collection: StickerCollection
        }
        struct Response: Sendable {
            let stickers: [Sticker]
            let activeCollection: StickerCollection
            let sortOrder: RewardsSortOrder
        }
        struct ViewModel: Sendable {
            let cells: [StickerCellViewModel]
            let collections: [CollectionTabViewModel]
            let isEmpty: Bool
            let emptyTitle: String
            let emptyMessage: String
            let activeCollection: StickerCollection
        }
    }

    // MARK: - SortStickers

    enum SortStickers {
        struct Request: Sendable {
            let sortOrder: RewardsSortOrder
        }
        struct Response: Sendable {
            let stickers: [Sticker]
            let sortOrder: RewardsSortOrder
            let activeCollection: StickerCollection
        }
        struct ViewModel: Sendable {
            let cells: [StickerCellViewModel]
            let sortOrder: RewardsSortOrder
        }
    }

    // MARK: - SearchStickers

    enum SearchStickers {
        struct Request: Sendable {
            let query: String
        }
        struct Response: Sendable {
            let stickers: [Sticker]
            let query: String
        }
        struct ViewModel: Sendable {
            let cells: [StickerCellViewModel]
            let query: String
            let isEmpty: Bool
            let emptyTitle: String
        }
    }

    // MARK: - OpenSticker

    enum OpenSticker {
        struct Request: Sendable {
            let id: String
        }
        struct Response: Sendable {
            let sticker: Sticker
        }
        struct ViewModel: Sendable {
            let detail: StickerDetailViewModel
        }
    }

    // MARK: - ClaimReward

    enum ClaimReward {
        struct Request: Sendable {
            let id: String
        }
        struct Response: Sendable {
            let sticker: Sticker
        }
        struct ViewModel: Sendable {
            let unlock: StickerUnlockViewModel
        }
    }

    // MARK: - ChangeAlbumTheme

    enum ChangeAlbumTheme {
        struct Request: Sendable {
            let theme: AlbumTheme
        }
        struct Response: Sendable {
            let theme: AlbumTheme
        }
        struct ViewModel: Sendable {
            let theme: AlbumTheme
            let confirmationMessage: String
        }
    }

    // MARK: - PrepareShare

    enum PrepareShare {
        struct Request: Sendable {
            let childId: String
        }
        struct Response: Sendable {
            let unlockedCount: Int
            let totalCount: Int
            let topStickers: [Sticker]
            let childName: String
        }
        struct ViewModel: Sendable {
            let shareText: String
            let topEmojis: String
        }
    }

    // MARK: - OpenAchievement

    enum OpenAchievement {
        struct Request: Sendable {
            let key: String
        }
        struct Response: Sendable {
            let achievement: RewardsAchievement
        }
        struct ViewModel: Sendable {
            let detail: AchievementDetailViewModel
        }
    }

    // MARK: - ClaimStreakReward

    enum ClaimStreakReward {
        struct Request: Sendable {
            let streakDays: Int
        }
        struct Response: Sendable {
            let reward: StreakReward
            let grantedSticker: Sticker?
        }
        struct ViewModel: Sendable {
            let toastMessage: String
            let grantedStickerEmoji: String?
        }
    }

    // MARK: - Failure

    enum Failure {
        struct Response: Sendable {
            let message: String
        }
        struct ViewModel: Sendable {
            let toastMessage: String
        }
    }
}

// MARK: - View Models

struct StickerCellViewModel: Sendable, Identifiable, Hashable {
    let id: String
    let emoji: String
    let name: String
    let isUnlocked: Bool
    let isNew: Bool
    let collection: StickerCollection
    let rarity: StickerRarity
    let accessibilityLabel: String
}

struct CollectionTabViewModel: Sendable, Identifiable, Hashable {
    var id: String { collection.rawValue }
    let collection: StickerCollection
    let title: String
    let emoji: String
    let isActive: Bool
    let count: Int
    let totalSlots: Int
    var isComplete: Bool { totalSlots > 0 && count == totalSlots }
}

struct StickerDetailViewModel: Sendable, Hashable, Identifiable {
    let id: String
    let emoji: String
    let name: String
    let collectionName: String
    let rarityLabel: String
    let rarityColor: Color
    let unlockCondition: String
    let unlockedDateLabel: String?
    let isUnlocked: Bool
    let linkedSoundId: String?
}

struct StickerUnlockViewModel: Sendable, Hashable, Identifiable {
    let id: String
    let emoji: String
    let name: String
    let rarity: StickerRarity
    let confettiEmojis: [String]
    let lyalyaVoiceLine: String
}

struct AchievementRowViewModel: Sendable, Identifiable, Hashable {
    let id: String
    let key: String
    let emoji: String
    let title: String
    let hint: String
    let medalEmoji: String
    let progress: Double
    let progressLabel: String
    let isUnlocked: Bool
    let unlockedDateLabel: String?
    let accessibilityLabel: String
}

struct AchievementDetailViewModel: Sendable, Identifiable {
    let id: String
    let key: String
    let emoji: String
    let title: String
    let hint: String
    let medalEmoji: String
    let progressLabel: String
    let isUnlocked: Bool
    let unlockedDateLabel: String?
}

struct StarsWalletViewModel: Sendable, Equatable {
    let totalEarned: Int
    let spent: Int
    let available: Int
    let accessibilityLabel: String
}

struct StreakBannerViewModel: Sendable, Identifiable, Equatable {
    let id: String
    let streakDays: Int
    let description: String
    let isClaimed: Bool
    let accessibilityLabel: String
}
