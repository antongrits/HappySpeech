import Foundation

// MARK: - HomeTasksDisplayLogic

@MainActor
protocol HomeTasksDisplayLogic: AnyObject {
    func displayFetch(_ viewModel: HomeTasksModels.Fetch.ViewModel)
    func displayUpdate(_ viewModel: HomeTasksModels.Update.ViewModel)
}
