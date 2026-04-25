import Foundation
import Observation

// MARK: - RewardsDisplayLogic

@MainActor
protocol RewardsDisplayLogic: AnyObject {
    func displayLoadRewards(_ viewModel: RewardsModels.LoadRewards.ViewModel)
    func displayFilterByCollection(_ viewModel: RewardsModels.FilterByCollection.ViewModel)
    func displayOpenSticker(_ viewModel: RewardsModels.OpenSticker.ViewModel)
    func displayClaimReward(_ viewModel: RewardsModels.ClaimReward.ViewModel)
    func displayFailure(_ viewModel: RewardsModels.Failure.ViewModel)
    func displayLoading(_ isLoading: Bool)
}

// MARK: - RewardsDisplay (Observable Store)

@Observable
@MainActor
final class RewardsDisplay: RewardsDisplayLogic {

    // Grid
    var cells: [StickerCellViewModel] = []
    var activeCollection: StickerCollection = .all

    // Tabs
    var collections: [CollectionTabViewModel] = []

    // Counters
    var unlockedCount: Int = 0
    var totalCount: Int = 0
    var progressLabel: String = ""
    var progress: Double = 0

    // Empty
    var isEmpty: Bool = false
    var emptyTitle: String = ""
    var emptyMessage: String = ""

    // Loading
    var isLoading: Bool = false

    // Detail (sheet)
    var pendingDetail: StickerDetailViewModel?

    // Unlock overlay
    var pendingUnlock: StickerUnlockViewModel?

    // Toast
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

    func displayOpenSticker(_ viewModel: RewardsModels.OpenSticker.ViewModel) {
        pendingDetail = viewModel.detail
    }

    func displayClaimReward(_ viewModel: RewardsModels.ClaimReward.ViewModel) {
        pendingUnlock = viewModel.unlock
    }

    func displayFailure(_ viewModel: RewardsModels.Failure.ViewModel) {
        toastMessage = viewModel.toastMessage
        isLoading = false
    }

    func displayLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
    }

    // MARK: - View helpers

    func clearToast() { toastMessage = nil }
    func consumeDetail() { pendingDetail = nil }
    func consumeUnlock() { pendingUnlock = nil }
}
