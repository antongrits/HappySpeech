import Foundation

// MARK: - SessionHistoryDisplayLogic

@MainActor
protocol SessionHistoryDisplayLogic: AnyObject {
    func displayFetch(_ viewModel: SessionHistoryModels.Fetch.ViewModel)
    func displayUpdate(_ viewModel: SessionHistoryModels.Update.ViewModel)
}
