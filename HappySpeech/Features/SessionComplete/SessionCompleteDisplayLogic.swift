import Foundation

// MARK: - SessionCompleteDisplayLogic

@MainActor
protocol SessionCompleteDisplayLogic: AnyObject {
    func displayFetch(_ viewModel: SessionCompleteModels.Fetch.ViewModel)
    func displayUpdate(_ viewModel: SessionCompleteModels.Update.ViewModel)
}
