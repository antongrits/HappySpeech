import Foundation
import OSLog

// MARK: - RewardsPresentationLogic

@MainActor
protocol RewardsPresentationLogic: AnyObject {
    func presentLoadRewards(_ response: RewardsModels.LoadRewards.Response)
    func presentFilterByCollection(_ response: RewardsModels.FilterByCollection.Response)
    func presentSortStickers(_ response: RewardsModels.SortStickers.Response)
    func presentSearchStickers(_ response: RewardsModels.SearchStickers.Response)
    func presentOpenSticker(_ response: RewardsModels.OpenSticker.Response)
    func presentClaimReward(_ response: RewardsModels.ClaimReward.Response)
    func presentChangeAlbumTheme(_ response: RewardsModels.ChangeAlbumTheme.Response)
    func presentPrepareShare(_ response: RewardsModels.PrepareShare.Response)
    func presentOpenAchievement(_ response: RewardsModels.OpenAchievement.Response)
    func presentClaimStreakReward(_ response: RewardsModels.ClaimStreakReward.Response)
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

    // MARK: - presentLoadRewards

    func presentLoadRewards(_ response: RewardsModels.LoadRewards.Response) {
        let cells = makeCells(
            stickers: response.stickers,
            filter: response.activeCollection,
            sortOrder: response.sortOrder
        )
        let collections = makeCollectionTabs(stickers: response.stickers, active: response.activeCollection)
        let achievementRows = makeAchievementRows(achievements: response.achievements)
        let walletVM = makeWalletViewModel(wallet: response.wallet)
        let streakBanners = makeStreakBanners(
            streakRewards: response.streakRewards,
            currentStreak: response.currentStreak
        )

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
            achievementRows: achievementRows,
            collections: collections,
            unlockedCount: unlockedCount,
            totalCount: totalCount,
            progressLabel: progressLabel,
            progress: progress,
            isEmpty: isEmpty,
            emptyTitle: emptyTitle,
            emptyMessage: emptyMessage,
            activeCollection: response.activeCollection,
            sortOrder: response.sortOrder,
            albumTheme: response.albumTheme,
            walletViewModel: walletVM,
            streakBanners: streakBanners,
            currentStreak: response.currentStreak
        ))
    }

    // MARK: - presentFilterByCollection

    func presentFilterByCollection(_ response: RewardsModels.FilterByCollection.Response) {
        let cells = makeCells(
            stickers: response.stickers,
            filter: response.activeCollection,
            sortOrder: response.sortOrder
        )
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

    // MARK: - presentSortStickers

    func presentSortStickers(_ response: RewardsModels.SortStickers.Response) {
        let cells = makeCells(
            stickers: response.stickers,
            filter: response.activeCollection,
            sortOrder: response.sortOrder
        )
        display?.displaySortStickers(.init(cells: cells, sortOrder: response.sortOrder))
    }

    // MARK: - presentSearchStickers

    func presentSearchStickers(_ response: RewardsModels.SearchStickers.Response) {
        let query = response.query
        let filtered: [Sticker]
        if query.isEmpty {
            filtered = response.stickers
        } else {
            let lower = query.lowercased()
            filtered = response.stickers.filter {
                $0.name.lowercased().contains(lower)
                    || $0.collection.displayName.lowercased().contains(lower)
                    || $0.rarity.displayName.lowercased().contains(lower)
            }
        }
        let cells = filtered.map { makeSingleCell($0) }
        let isEmpty = cells.isEmpty
        let emptyTitle = query.isEmpty
            ? ""
            : String(format: String(localized: "rewards.search.empty"), query)

        display?.displaySearchStickers(.init(
            cells: cells,
            query: query,
            isEmpty: isEmpty,
            emptyTitle: emptyTitle
        ))
    }

    // MARK: - presentOpenSticker

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
            rarityLabel: sticker.rarity.displayName,
            rarityColor: sticker.rarity.borderColor,
            unlockCondition: sticker.unlockCondition,
            unlockedDateLabel: dateLabel,
            isUnlocked: sticker.isUnlocked,
            linkedSoundId: sticker.linkedSoundId
        )
        display?.displayOpenSticker(.init(detail: detail))
    }

    // MARK: - presentClaimReward

    func presentClaimReward(_ response: RewardsModels.ClaimReward.Response) {
        let sticker = response.sticker
        let voiceLine: String
        switch sticker.rarity {
        case .legendary:
            voiceLine = String(localized: "rewards.lyalya.legendary")
        case .epic:
            voiceLine = String(localized: "rewards.lyalya.epic")
        case .rare:
            voiceLine = String(localized: "rewards.lyalya.rare")
        case .common:
            voiceLine = String(localized: "rewards.lyalya.common")
        }
        let confetti: [String]
        switch sticker.rarity {
        case .legendary: confetti = ["🌈", "✨", "⭐", "💫", "🌟", sticker.emoji, "🎉", "🏆"]
        case .epic:      confetti = ["✨", "💫", "⭐", sticker.emoji, "🎉", "🔮"]
        case .rare:      confetti = ["⭐", "🌟", sticker.emoji, "🎉", "💙"]
        case .common:    confetti = ["🎉", "✨", "⭐", sticker.emoji]
        }
        let unlock = StickerUnlockViewModel(
            id: sticker.id,
            emoji: sticker.emoji,
            name: sticker.name,
            rarity: sticker.rarity,
            confettiEmojis: confetti,
            lyalyaVoiceLine: voiceLine
        )
        display?.displayClaimReward(.init(unlock: unlock))
    }

    // MARK: - presentChangeAlbumTheme

    func presentChangeAlbumTheme(_ response: RewardsModels.ChangeAlbumTheme.Response) {
        let message = String(
            format: String(localized: "rewards.theme.changed"),
            response.theme.displayName
        )
        display?.displayChangeAlbumTheme(.init(
            theme: response.theme,
            confirmationMessage: message
        ))
    }

    // MARK: - presentPrepareShare

    func presentPrepareShare(_ response: RewardsModels.PrepareShare.Response) {
        let topEmojis = response.topStickers.map(\.emoji).joined(separator: " ")
        let shareText = String(
            format: String(localized: "rewards.share.text"),
            response.unlockedCount,
            response.totalCount,
            topEmojis
        )
        display?.displayPrepareShare(.init(shareText: shareText, topEmojis: topEmojis))
    }

    // MARK: - presentOpenAchievement

    func presentOpenAchievement(_ response: RewardsModels.OpenAchievement.Response) {
        let ach = response.achievement
        let medalEmoji = medalEmoji(for: ach.medal)
        let dateLabel: String? = ach.unlockedAt.map {
            String(
                format: String(localized: "rewards.detail.unlockedOn"),
                Self.dateFormatter.string(from: $0)
            )
        }
        let progressLabel: String
        if ach.isUnlocked {
            progressLabel = String(localized: "rewards.achievement.done")
        } else {
            progressLabel = String(
                format: String(localized: "rewards.achievement.progress"),
                ach.currentProgress,
                ach.requiredProgress
            )
        }
        display?.displayOpenAchievement(.init(detail: AchievementDetailViewModel(
            id: ach.id,
            key: ach.key,
            emoji: ach.emoji,
            title: ach.title,
            hint: ach.hint,
            medalEmoji: medalEmoji,
            progressLabel: progressLabel,
            isUnlocked: ach.isUnlocked,
            unlockedDateLabel: dateLabel
        )))
    }

    // MARK: - presentClaimStreakReward

    func presentClaimStreakReward(_ response: RewardsModels.ClaimStreakReward.Response) {
        let message: String
        if let sticker = response.grantedSticker {
            message = String(
                format: String(localized: "rewards.streak.claimed.sticker"),
                sticker.emoji,
                sticker.name
            )
        } else {
            message = String(localized: "rewards.streak.claimed.noSticker")
        }
        display?.displayClaimStreakReward(.init(
            toastMessage: message,
            grantedStickerEmoji: response.grantedSticker?.emoji
        ))
    }

    // MARK: - presentFailure

    func presentFailure(_ response: RewardsModels.Failure.Response) {
        logger.error("failure: \(response.message, privacy: .public)")
        display?.displayFailure(.init(toastMessage: response.message))
    }

    // MARK: - Private: Cell Builders

    private func makeCells(
        stickers: [Sticker],
        filter: StickerCollection,
        sortOrder: RewardsSortOrder
    ) -> [StickerCellViewModel] {
        let filtered: [Sticker] = (filter == .all)
            ? stickers
            : stickers.filter { $0.collection == filter }

        let sorted: [Sticker]
        switch sortOrder {
        case .byCollection:
            sorted = filtered.sorted { $0.collection.rawValue < $1.collection.rawValue }
        case .byDate:
            sorted = filtered.sorted { lhs, rhs in
                switch (lhs.unlockedAt, rhs.unlockedAt) {
                case let (lDate?, rDate?): return lDate > rDate
                case (nil, _?):    return false
                case (_?, nil):    return true
                case (nil, nil):   return lhs.id < rhs.id
                }
            }
        case .byRarity:
            sorted = filtered.sorted { $0.rarity > $1.rarity }
        }

        return sorted.map { makeSingleCell($0) }
    }

    private func makeSingleCell(_ sticker: Sticker) -> StickerCellViewModel {
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
            rarity: sticker.rarity,
            accessibilityLabel: label
        )
    }

    private func makeCollectionTabs(stickers: [Sticker], active: StickerCollection) -> [CollectionTabViewModel] {
        StickerCollection.allCases.map { collection in
            let inCollection: [Sticker]
            if collection == .all {
                inCollection = stickers
            } else {
                inCollection = stickers.filter { $0.collection == collection }
            }
            let count = inCollection.count
            let slots = collection.totalSlots
            return CollectionTabViewModel(
                collection: collection,
                title: collection.displayName,
                emoji: collection.emoji,
                isActive: collection == active,
                count: count,
                totalSlots: slots
            )
        }
    }

    private func makeAchievementRows(achievements: [RewardsAchievement]) -> [AchievementRowViewModel] {
        achievements.map { ach in
            let medalEmojiStr = medalEmoji(for: ach.medal)
            let dateLabel: String? = ach.unlockedAt.map {
                String(
                    format: String(localized: "rewards.detail.unlockedOn"),
                    Self.dateFormatter.string(from: $0)
                )
            }
            let progressLabel: String
            if ach.isUnlocked {
                progressLabel = String(localized: "rewards.achievement.done")
            } else {
                progressLabel = String(
                    format: String(localized: "rewards.achievement.progress"),
                    ach.currentProgress,
                    ach.requiredProgress
                )
            }
            let a11yLabel: String
            if ach.isUnlocked {
                a11yLabel = String(
                    format: String(localized: "rewards.a11y.achievementUnlocked"),
                    ach.title
                )
            } else {
                a11yLabel = String(
                    format: String(localized: "rewards.a11y.achievementLocked"),
                    ach.title,
                    ach.currentProgress,
                    ach.requiredProgress
                )
            }
            return AchievementRowViewModel(
                id: ach.id,
                key: ach.key,
                emoji: ach.emoji,
                title: ach.title,
                hint: ach.hint,
                medalEmoji: medalEmojiStr,
                progress: ach.progressFraction,
                progressLabel: progressLabel,
                isUnlocked: ach.isUnlocked,
                unlockedDateLabel: dateLabel,
                accessibilityLabel: a11yLabel
            )
        }
    }

    private func makeWalletViewModel(wallet: StarsWallet) -> StarsWalletViewModel {
        let label = String(
            format: String(localized: "rewards.wallet.a11y"),
            wallet.available,
            wallet.totalEarned
        )
        return StarsWalletViewModel(
            totalEarned: wallet.totalEarned,
            spent: wallet.totalSpent,
            available: wallet.available,
            accessibilityLabel: label
        )
    }

    private func makeStreakBanners(
        streakRewards: [StreakReward],
        currentStreak: Int
    ) -> [StreakBannerViewModel] {
        streakRewards.map { reward in
            let isReachable = currentStreak >= reward.streakDays
            let label: String
            if reward.isClaimed {
                label = String(
                    format: String(localized: "rewards.streak.banner.a11y.claimed"),
                    reward.streakDays
                )
            } else if isReachable {
                label = String(
                    format: String(localized: "rewards.streak.banner.a11y.claimable"),
                    reward.streakDays
                )
            } else {
                label = String(
                    format: String(localized: "rewards.streak.banner.a11y.locked"),
                    reward.streakDays,
                    currentStreak
                )
            }
            return StreakBannerViewModel(
                id: "streak_\(reward.streakDays)",
                streakDays: reward.streakDays,
                description: reward.rewardDescription,
                isClaimed: reward.isClaimed,
                accessibilityLabel: label
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

    private func medalEmoji(for medal: RewardsAchievement.Medal) -> String {
        switch medal {
        case .bronze:  return "🥉"
        case .silver:  return "🥈"
        case .gold:    return "🥇"
        }
    }
}
