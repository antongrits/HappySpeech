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
        let s = response.sticker
        let dateLabel: String? = s.unlockedAt.map {
            String(
                format: String(localized: "rewards.detail.unlockedOn"),
                Self.dateFormatter.string(from: $0)
            )
        }
        let detail = StickerDetailViewModel(
            id: s.id,
            emoji: s.emoji,
            name: s.name,
            collectionName: s.collection.displayName,
            unlockCondition: s.unlockCondition,
            unlockedDateLabel: dateLabel,
            isUnlocked: s.isUnlocked
        )
        display?.displayOpenSticker(.init(detail: detail))
    }

    func presentClaimReward(_ response: RewardsModels.ClaimReward.Response) {
        let s = response.sticker
        let unlock = StickerUnlockViewModel(
            id: s.id,
            emoji: s.emoji,
            name: s.name,
            confettiEmojis: ["🎉", "✨", "⭐", "🌟", "💫", s.emoji]
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
        return filtered.map { s in
            let label: String
            if s.isUnlocked {
                label = String(format: String(localized: "rewards.a11y.cellUnlocked"), s.name)
            } else {
                label = String(format: String(localized: "rewards.a11y.cellLocked"), s.name)
            }
            return StickerCellViewModel(
                id: s.id,
                emoji: s.emoji,
                name: s.name,
                isUnlocked: s.isUnlocked,
                isNew: s.isNew,
                collection: s.collection,
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
