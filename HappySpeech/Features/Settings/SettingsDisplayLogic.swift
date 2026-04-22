import Foundation

// MARK: - SettingsDisplayLogic

@MainActor
protocol SettingsDisplayLogic: AnyObject {
    func displayFetch(_ viewModel: SettingsModels.Fetch.ViewModel)
    func displayUpdate(_ viewModel: SettingsModels.Update.ViewModel)
}
