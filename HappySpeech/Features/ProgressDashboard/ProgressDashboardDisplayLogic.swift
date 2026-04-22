import Foundation

// MARK: - ProgressDashboardDisplayLogic

@MainActor
protocol ProgressDashboardDisplayLogic: AnyObject {
    func displayFetch(_ viewModel: ProgressDashboardModels.Fetch.ViewModel)
    func displayUpdate(_ viewModel: ProgressDashboardModels.Update.ViewModel)
}
