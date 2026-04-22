import Foundation

// MARK: - DemoDisplayLogic

@MainActor
protocol DemoDisplayLogic: AnyObject {
    func displayFetch(_ viewModel: DemoModels.Fetch.ViewModel)
    func displayUpdate(_ viewModel: DemoModels.Update.ViewModel)
}
