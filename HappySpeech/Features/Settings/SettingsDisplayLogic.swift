import Foundation
import Observation

// MARK: - SettingsDisplayLogic

@MainActor
protocol SettingsDisplayLogic: AnyObject {
    func displayLoadSettings(_ viewModel: SettingsModels.LoadSettings.ViewModel)
    func displayUpdateTheme(_ viewModel: SettingsModels.UpdateTheme.ViewModel)
    func displayUpdateProfile(_ viewModel: SettingsModels.UpdateProfile.ViewModel)
    func displayToggleNotifications(_ viewModel: SettingsModels.ToggleNotifications.ViewModel)
    func displayUpdateContent(_ viewModel: SettingsModels.UpdateContent.ViewModel)
    func displayExportData(_ viewModel: SettingsModels.ExportData.ViewModel)
    func displayClearCache(_ viewModel: SettingsModels.ClearCache.ViewModel)
    func displayConnectSpecialist(_ viewModel: SettingsModels.ConnectSpecialist.ViewModel)
    func displayFailure(_ viewModel: SettingsModels.Failure.ViewModel)
    func displayLoading(_ isLoading: Bool)
}

// MARK: - SettingsDisplay (Observable Store)

@Observable
@MainActor
final class SettingsDisplay: SettingsDisplayLogic {

    var settings: AppSettings = .default
    var appVersionLine: String = ""
    var availableAvatars: [String] = []
    var availableAges: [Int] = []

    var isLoading: Bool = false
    var toastMessage: String?
    var toastIsError: Bool = false

    // MARK: - SettingsDisplayLogic

    func displayLoadSettings(_ viewModel: SettingsModels.LoadSettings.ViewModel) {
        settings = viewModel.settings
        appVersionLine = viewModel.appVersionLine
        availableAvatars = viewModel.availableAvatars
        availableAges = viewModel.availableAges
        isLoading = false
    }

    func displayUpdateTheme(_ viewModel: SettingsModels.UpdateTheme.ViewModel) {
        settings = viewModel.settings
        toastMessage = viewModel.toastMessage
        toastIsError = false
    }

    func displayUpdateProfile(_ viewModel: SettingsModels.UpdateProfile.ViewModel) {
        settings = viewModel.settings
        toastMessage = viewModel.toastMessage
        toastIsError = false
    }

    func displayToggleNotifications(_ viewModel: SettingsModels.ToggleNotifications.ViewModel) {
        settings = viewModel.settings
        toastMessage = viewModel.toastMessage
        toastIsError = viewModel.toastIsError
    }

    func displayUpdateContent(_ viewModel: SettingsModels.UpdateContent.ViewModel) {
        settings = viewModel.settings
        toastMessage = viewModel.toastMessage
        toastIsError = false
    }

    func displayExportData(_ viewModel: SettingsModels.ExportData.ViewModel) {
        toastMessage = viewModel.toastMessage
        toastIsError = viewModel.toastIsError
        isLoading = false
    }

    func displayClearCache(_ viewModel: SettingsModels.ClearCache.ViewModel) {
        toastMessage = viewModel.toastMessage
        toastIsError = false
        isLoading = false
    }

    func displayConnectSpecialist(_ viewModel: SettingsModels.ConnectSpecialist.ViewModel) {
        settings = viewModel.settings
        toastMessage = viewModel.toastMessage
        toastIsError = viewModel.toastIsError
        isLoading = false
    }

    func displayFailure(_ viewModel: SettingsModels.Failure.ViewModel) {
        toastMessage = viewModel.toastMessage
        toastIsError = true
        isLoading = false
    }

    func displayLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
    }

    func clearToast() {
        toastMessage = nil
        toastIsError = false
    }
}
