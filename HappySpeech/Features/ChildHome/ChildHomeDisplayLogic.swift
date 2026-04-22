import Foundation

// MARK: - ChildHomeDisplayLogic

@MainActor
protocol ChildHomeDisplayLogic: AnyObject {
    func displayFetch(_ viewModel: ChildHomeModels.Fetch.ViewModel)
}
