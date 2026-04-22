import Foundation

// MARK: - ARZoneDisplayLogic

@MainActor
protocol ARZoneDisplayLogic: AnyObject {
    func displayFetch(_ viewModel: ARZoneModels.Fetch.ViewModel)
    func displayUpdate(_ viewModel: ARZoneModels.Update.ViewModel)
}
