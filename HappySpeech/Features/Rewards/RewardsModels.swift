import Foundation
import SwiftUI

// MARK: - Rewards VIP Models
//
// Экран коллекции стикеров (kid-контур). Поддерживает фильтр по коллекциям,
// детальный просмотр, разблокировку с confetti-overlay'ем.

// MARK: - Sticker (DTO)

public struct Sticker: Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public let emoji: String
    public let name: String
    public let collection: StickerCollection
    public var isUnlocked: Bool
    public var isNew: Bool
    public let unlockCondition: String
    public let unlockedAt: Date?

    public init(
        id: String,
        emoji: String,
        name: String,
        collection: StickerCollection,
        isUnlocked: Bool,
        isNew: Bool,
        unlockCondition: String,
        unlockedAt: Date?
    ) {
        self.id = id
        self.emoji = emoji
        self.name = name
        self.collection = collection
        self.isUnlocked = isUnlocked
        self.isNew = isNew
        self.unlockCondition = unlockCondition
        self.unlockedAt = unlockedAt
    }
}

// MARK: - StickerCollection

public enum StickerCollection: String, Sendable, CaseIterable, Identifiable {
    case all
    case stars
    case animals
    case letters
    case holidays

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .all:      return String(localized: "rewards.collection.all")
        case .stars:    return String(localized: "rewards.collection.stars")
        case .animals:  return String(localized: "rewards.collection.animals")
        case .letters:  return String(localized: "rewards.collection.letters")
        case .holidays: return String(localized: "rewards.collection.holidays")
        }
    }

    public var emoji: String {
        switch self {
        case .all:      return "🎁"
        case .stars:    return "⭐"
        case .animals:  return "🐾"
        case .letters:  return "🔤"
        case .holidays: return "🎉"
        }
    }
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
            let activeCollection: StickerCollection
        }
        struct ViewModel: Sendable {
            let cells: [StickerCellViewModel]
            let collections: [CollectionTabViewModel]
            let unlockedCount: Int
            let totalCount: Int
            let progressLabel: String
            let progress: Double
            let isEmpty: Bool
            let emptyTitle: String
            let emptyMessage: String
            let activeCollection: StickerCollection
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
    let accessibilityLabel: String
}

struct CollectionTabViewModel: Sendable, Identifiable, Hashable {
    var id: String { collection.rawValue }
    let collection: StickerCollection
    let title: String
    let emoji: String
    let isActive: Bool
    let count: Int
}

struct StickerDetailViewModel: Sendable, Hashable, Identifiable {
    let id: String
    let emoji: String
    let name: String
    let collectionName: String
    let unlockCondition: String
    let unlockedDateLabel: String?
    let isUnlocked: Bool
}

struct StickerUnlockViewModel: Sendable, Hashable, Identifiable {
    let id: String
    let emoji: String
    let name: String
    let confettiEmojis: [String]
}
