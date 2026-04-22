import Foundation

// MARK: - WorldMapDisplayLogic

@MainActor
protocol WorldMapDisplayLogic: AnyObject {
    func displayFetch(_ viewModel: WorldMapModels.Fetch.ViewModel)
    func displayUpdate(_ viewModel: WorldMapModels.Update.ViewModel)
}
