import Foundation

// MARK: - ParentHomeDisplayLogic

@MainActor
protocol ParentHomeDisplayLogic: AnyObject {
    func displayFetch(_ viewModel: ParentHomeModels.Fetch.ViewModel)
    func displayLoading(_ isLoading: Bool)
    func displayEmptyState()
}
