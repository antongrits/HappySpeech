import Foundation
import Observation

// MARK: - RewardsDisplayLogic

@MainActor
protocol RewardsDisplayLogic: AnyObject {
    func displayLoadRewards(_ viewModel: RewardsModels.LoadRewards.ViewModel)
    func displayFilterByCollection(_ viewModel: RewardsModels.FilterByCollection.ViewModel)
    func displaySortStickers(_ viewModel: RewardsModels.SortStickers.ViewModel)
    func displaySearchStickers(_ viewModel: RewardsModels.SearchStickers.ViewModel)
    func displayOpenSticker(_ viewModel: RewardsModels.OpenSticker.ViewModel)
    func displayClaimReward(_ viewModel: RewardsModels.ClaimReward.ViewModel)
    func displayChangeAlbumTheme(_ viewModel: RewardsModels.ChangeAlbumTheme.ViewModel)
    func displayPrepareShare(_ viewModel: RewardsModels.PrepareShare.ViewModel)
    func displayOpenAchievement(_ viewModel: RewardsModels.OpenAchievement.ViewModel)
    func displayClaimStreakReward(_ viewModel: RewardsModels.ClaimStreakReward.ViewModel)
    func displayFailure(_ viewModel: RewardsModels.Failure.ViewModel)
    func displayLoading(_ isLoading: Bool)
}

// MARK: - RewardsDisplay (Observable Store)

@Observable
@MainActor
final class RewardsDisplay: RewardsDisplayLogic {

    // MARK: - Grid / Stickers

    var cells: [StickerCellViewModel] = []
    var activeCollection: StickerCollection = .all
    var sortOrder: RewardsSortOrder = .byCollection
    var albumTheme: AlbumTheme = .bright

    // MARK: - Collection Tabs

    var collections: [CollectionTabViewModel] = []

    // MARK: - Counters

    var unlockedCount: Int = 0
    var totalCount: Int = 0
    var progressLabel: String = ""
    var progress: Double = 0
    var currentStreak: Int = 0

    // MARK: - Empty States

    var isEmpty: Bool = false
    var emptyTitle: String = ""
    var emptyMessage: String = ""

    // MARK: - Achievements

    var achievementRows: [AchievementRowViewModel] = []
    var pendingAchievementDetail: AchievementDetailViewModel?

    // MARK: - Wallet

    var walletViewModel: StarsWalletViewModel = StarsWalletViewModel(
        totalEarned: 0,
        spent: 0,
        available: 0,
        accessibilityLabel: ""
    )

    // MARK: - Streak Banners

    var streakBanners: [StreakBannerViewModel] = []

    // MARK: - Search

    var searchQuery: String = ""
    var searchCells: [StickerCellViewModel] = []
    var isSearchEmpty: Bool = false
    var searchEmptyTitle: String = ""

    // MARK: - Share

    var pendingShareText: String?
    var pendingShareEmojis: String?

    // MARK: - Loading

    var isLoading: Bool = false

    // MARK: - Detail (sheet)

    var pendingDetail: StickerDetailViewModel?

    // MARK: - Unlock overlay

    var pendingUnlock: StickerUnlockViewModel?

    // MARK: - Toast

    var toastMessage: String?

    // MARK: - DisplayLogic

    func displayLoadRewards(_ viewModel: RewardsModels.LoadRewards.ViewModel) {
        cells = viewModel.cells
        collections = viewModel.collections
        unlockedCount = viewModel.unlockedCount
        totalCount = viewModel.totalCount
        progressLabel = viewModel.progressLabel
        progress = viewModel.progress
        isEmpty = viewModel.isEmpty
        emptyTitle = viewModel.emptyTitle
        emptyMessage = viewModel.emptyMessage
        activeCollection = viewModel.activeCollection
        sortOrder = viewModel.sortOrder
        albumTheme = viewModel.albumTheme
        walletViewModel = viewModel.walletViewModel
        achievementRows = viewModel.achievementRows
        streakBanners = viewModel.streakBanners
        currentStreak = viewModel.currentStreak
        isLoading = false
    }

    func displayFilterByCollection(_ viewModel: RewardsModels.FilterByCollection.ViewModel) {
        cells = viewModel.cells
        collections = viewModel.collections
        isEmpty = viewModel.isEmpty
        emptyTitle = viewModel.emptyTitle
        emptyMessage = viewModel.emptyMessage
        activeCollection = viewModel.activeCollection
    }

    func displaySortStickers(_ viewModel: RewardsModels.SortStickers.ViewModel) {
        cells = viewModel.cells
        sortOrder = viewModel.sortOrder
    }

    func displaySearchStickers(_ viewModel: RewardsModels.SearchStickers.ViewModel) {
        searchCells = viewModel.cells
        searchQuery = viewModel.query
        isSearchEmpty = viewModel.isEmpty
        searchEmptyTitle = viewModel.emptyTitle
    }

    func displayOpenSticker(_ viewModel: RewardsModels.OpenSticker.ViewModel) {
        pendingDetail = viewModel.detail
    }

    func displayClaimReward(_ viewModel: RewardsModels.ClaimReward.ViewModel) {
        pendingUnlock = viewModel.unlock
    }

    func displayChangeAlbumTheme(_ viewModel: RewardsModels.ChangeAlbumTheme.ViewModel) {
        albumTheme = viewModel.theme
    }

    func displayPrepareShare(_ viewModel: RewardsModels.PrepareShare.ViewModel) {
        pendingShareText = viewModel.shareText
        pendingShareEmojis = viewModel.topEmojis
    }

    func displayOpenAchievement(_ viewModel: RewardsModels.OpenAchievement.ViewModel) {
        pendingAchievementDetail = viewModel.detail
    }

    func displayClaimStreakReward(_ viewModel: RewardsModels.ClaimStreakReward.ViewModel) {
        toastMessage = viewModel.toastMessage
    }

    func displayFailure(_ viewModel: RewardsModels.Failure.ViewModel) {
        toastMessage = viewModel.toastMessage
        isLoading = false
    }

    func displayLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
    }

    // MARK: - View Helpers

    func clearToast() { toastMessage = nil }
    func consumeDetail() { pendingDetail = nil }
    func consumeUnlock() { pendingUnlock = nil }
    func consumeAchievementDetail() { pendingAchievementDetail = nil }
    func consumeShare() { pendingShareText = nil; pendingShareEmojis = nil }
}
