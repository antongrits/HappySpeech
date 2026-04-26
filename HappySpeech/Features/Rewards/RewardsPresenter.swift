import Foundation
import OSLog

// MARK: - RewardsPresentationLogic

@MainActor
protocol RewardsPresentationLogic: AnyObject {
    func presentLoadRewards(_ response: RewardsModels.LoadRewards.Response)
    func presentFilterByCollection(_ response: RewardsModels.FilterByCollection.Response)
    func presentOpenSticker(_ response: RewardsModels.OpenSticker.Response)
    func presentClaimReward(_ response: RewardsModels.ClaimReward.Response)
    func presentFailure(_ response: RewardsModels.Failure.Response)
}

// MARK: - RewardsPresenter

@MainActor
final class RewardsPresenter: RewardsPresentationLogic {

    // MARK: - Collaborators

    weak var display: (any RewardsDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "RewardsPresenter")

    // MARK: - Formatters

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "d MMMM yyyy"
        return df
    }()

    // MARK: - PresentationLogic

    func presentLoadRewards(_ response: RewardsModels.LoadRewards.Response) {
        let cells = makeCells(stickers: response.stickers, filter: response.activeCollection)
        let collections = makeCollectionTabs(stickers: response.stickers, active: response.activeCollection)

        let unlockedCount = response.stickers.filter(\.isUnlocked).count
        let totalCount = response.stickers.count
        let progressLabel = String(
            format: String(localized: "rewards.progress.label"),
            unlockedCount,
            totalCount
        )
        let progress = totalCount > 0 ? Double(unlockedCount) / Double(totalCount) : 0

        let isEmpty = cells.isEmpty
        let (emptyTitle, emptyMessage) = makeEmptyTexts(
            collection: response.activeCollection,
            isFilterActive: response.activeCollection != .all
        )

        display?.displayLoadRewards(.init(
            cells: cells,
            collections: collections,
            unlockedCount: unlockedCount,
            totalCount: totalCount,
            progressLabel: progressLabel,
            progress: progress,
            isEmpty: isEmpty,
            emptyTitle: emptyTitle,
            emptyMessage: emptyMessage,
            activeCollection: response.activeCollection
        ))
    }

    func presentFilterByCollection(_ response: RewardsModels.FilterByCollection.Response) {
        let cells = makeCells(stickers: response.stickers, filter: response.activeCollection)
        let collections = makeCollectionTabs(stickers: response.stickers, active: response.activeCollection)

        let isEmpty = cells.isEmpty
        let (emptyTitle, emptyMessage) = makeEmptyTexts(
            collection: response.activeCollection,
            isFilterActive: response.activeCollection != .all
        )

        display?.displayFilterByCollection(.init(
            cells: cells,
            collections: collections,
            isEmpty: isEmpty,
            emptyTitle: emptyTitle,
            emptyMessage: emptyMessage,
            activeCollection: response.activeCollection
        ))
    }

    func presentOpenSticker(_ response: RewardsModels.OpenSticker.Response) {
        let sticker = response.sticker
        let dateLabel: String? = sticker.unlockedAt.map {
            String(
                format: String(localized: "rewards.detail.unlockedOn"),
                Self.dateFormatter.string(from: $0)
            )
        }
        let detail = StickerDetailViewModel(
            id: sticker.id,
            emoji: sticker.emoji,
            name: sticker.name,
            collectionName: sticker.collection.displayName,
            unlockCondition: sticker.unlockCondition,
            unlockedDateLabel: dateLabel,
            isUnlocked: sticker.isUnlocked
        )
        display?.displayOpenSticker(.init(detail: detail))
    }

    func presentClaimReward(_ response: RewardsModels.ClaimReward.Response) {
        let sticker = response.sticker
        let unlock = StickerUnlockViewModel(
            id: sticker.id,
            emoji: sticker.emoji,
            name: sticker.name,
            confettiEmojis: ["🎉", "✨", "⭐", "🌟", "💫", sticker.emoji]
        )
        display?.displayClaimReward(.init(unlock: unlock))
    }

    func presentFailure(_ response: RewardsModels.Failure.Response) {
        logger.error("failure: \(response.message, privacy: .public)")
        display?.displayFailure(.init(toastMessage: response.message))
    }

    // MARK: - Private

    private func makeCells(stickers: [Sticker], filter: StickerCollection) -> [StickerCellViewModel] {
        let filtered: [Sticker] = (filter == .all)
            ? stickers
            : stickers.filter { $0.collection == filter }
        return filtered.map { sticker in
            let label: String
            if sticker.isUnlocked {
                label = String(format: String(localized: "rewards.a11y.cellUnlocked"), sticker.name)
            } else {
                label = String(format: String(localized: "rewards.a11y.cellLocked"), sticker.name)
            }
            return StickerCellViewModel(
                id: sticker.id,
                emoji: sticker.emoji,
                name: sticker.name,
                isUnlocked: sticker.isUnlocked,
                isNew: sticker.isNew,
                collection: sticker.collection,
                accessibilityLabel: label
            )
        }
    }

    private func makeCollectionTabs(stickers: [Sticker], active: StickerCollection) -> [CollectionTabViewModel] {
        StickerCollection.allCases.map { collection in
            let count: Int
            if collection == .all {
                count = stickers.count
            } else {
                count = stickers.filter { $0.collection == collection }.count
            }
            return CollectionTabViewModel(
                collection: collection,
                title: collection.displayName,
                emoji: collection.emoji,
                isActive: collection == active,
                count: count
            )
        }
    }

    private func makeEmptyTexts(collection: StickerCollection, isFilterActive: Bool) -> (String, String) {
        if isFilterActive {
            return (
                String(localized: "rewards.empty.filter.title"),
                String(format: String(localized: "rewards.empty.filter.message"), collection.displayName)
            )
        }
        return (
            String(localized: "rewards.empty.all.title"),
            String(localized: "rewards.empty.all.message")
        )
    }
}
