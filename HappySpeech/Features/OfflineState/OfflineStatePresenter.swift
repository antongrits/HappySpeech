import Foundation

// MARK: - OfflineStatePresentationLogic

@MainActor
protocol OfflineStatePresentationLogic: AnyObject {
    func presentFetch(_ response: OfflineStateModels.Fetch.Response)
    func presentUpdate(_ response: OfflineStateModels.Update.Response)
}

// MARK: - OfflineStatePresenter

@MainActor
final class OfflineStatePresenter: OfflineStatePresentationLogic {

    weak var viewModel: (any OfflineStateDisplayLogic)?

    func presentFetch(_ response: OfflineStateModels.Fetch.Response) {
        let badge = Self.formatPendingBadge(count: response.pendingCount)
        let vm = OfflineStateModels.Fetch.ViewModel(
            activeChildId: response.activeChildId,
            pendingCount: response.pendingCount,
            pendingBadgeText: badge,
            hasActiveChild: response.activeChildId != nil
        )
        viewModel?.displayFetch(vm)
    }

    func presentUpdate(_ response: OfflineStateModels.Update.Response) {
        let vm = OfflineStateModels.Update.ViewModel(
            kind: response.kind,
            isRetrying: false,
            isConnected: response.isConnected
        )
        viewModel?.displayUpdate(vm)
    }

    // MARK: - Helpers

    static func formatPendingBadge(count: Int) -> String {
        // Russian plural forms for items awaiting sync.
        let format = String(localized: "pending.sync.badge")
        return String.localizedStringWithFormat(format, count)
    }
}
