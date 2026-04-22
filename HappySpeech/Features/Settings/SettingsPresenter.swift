import Foundation

// MARK: - SettingsPresentationLogic

@MainActor
protocol SettingsPresentationLogic: AnyObject {
    func presentFetch(_ response: SettingsModels.Fetch.Response)
    func presentUpdate(_ response: SettingsModels.Update.Response)
}

// MARK: - SettingsPresenter

@MainActor
final class SettingsPresenter: SettingsPresentationLogic {

    weak var viewModel: (any SettingsDisplayLogic)?

    func presentFetch(_ response: SettingsModels.Fetch.Response) {
        let vm = SettingsModels.Fetch.ViewModel()
        viewModel?.displayFetch(vm)
    }

    func presentUpdate(_ response: SettingsModels.Update.Response) {
        let vm = SettingsModels.Update.ViewModel()
        viewModel?.displayUpdate(vm)
    }
}
