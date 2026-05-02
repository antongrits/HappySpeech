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
    func displayLoadModelPacks(_ viewModel: SettingsModels.LoadModelPacks.ViewModel)
    func displayDownloadModelPack(_ viewModel: SettingsModels.DownloadModelPack.ViewModel)
    func displayDeleteModelPack(_ viewModel: SettingsModels.DeleteModelPack.ViewModel)
    func displayLoadLicenses(_ viewModel: SettingsModels.LoadLicenses.ViewModel)
    func displayExportShare(_ viewModel: SettingsModels.ExportShare.ViewModel)
    func displayFailure(_ viewModel: SettingsModels.Failure.ViewModel)
    func displayLoading(_ isLoading: Bool)
    /// L9
    func displayToggleKidDailyReminder(_ viewModel: SettingsModels.ToggleKidDailyReminder.ViewModel)
    func displayToggleWeeklyParentSummary(_ viewModel: SettingsModels.ToggleWeeklyParentSummary.ViewModel)
    /// T (v12)
    func displayUpdateHaptics(_ viewModel: SettingsModels.UpdateHaptics.ViewModel)
    /// G (v14): Performance Monitoring opt-in
    func displayTogglePerformanceMonitoring(_ viewModel: SettingsModels.TogglePerformanceMonitoring.ViewModel)
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

    // Models / licenses / share state.
    var asrModelItems: [ModelPackRowVM] = []
    var llmModelItems: [ModelPackRowVM] = []
    var licenses: [OpenSourceLicenseVM] = []
    var shareFileURL: URL?

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
        if let url = viewModel.fileURL {
            shareFileURL = url
        }
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

    func displayLoadModelPacks(_ viewModel: SettingsModels.LoadModelPacks.ViewModel) {
        asrModelItems = viewModel.asrItems
        llmModelItems = viewModel.llmItems
    }

    func displayDownloadModelPack(_ viewModel: SettingsModels.DownloadModelPack.ViewModel) {
        toastMessage = viewModel.toastMessage
        toastIsError = viewModel.toastIsError
    }

    func displayDeleteModelPack(_ viewModel: SettingsModels.DeleteModelPack.ViewModel) {
        toastMessage = viewModel.toastMessage
        toastIsError = viewModel.toastIsError
    }

    func displayLoadLicenses(_ viewModel: SettingsModels.LoadLicenses.ViewModel) {
        licenses = viewModel.licenses
    }

    func displayExportShare(_ viewModel: SettingsModels.ExportShare.ViewModel) {
        shareFileURL = viewModel.fileURL
        toastMessage = viewModel.toastMessage
        toastIsError = viewModel.toastIsError
    }

    func displayFailure(_ viewModel: SettingsModels.Failure.ViewModel) {
        toastMessage = viewModel.toastMessage
        toastIsError = true
        isLoading = false
    }

    func displayLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
    }

    func displayToggleKidDailyReminder(_ viewModel: SettingsModels.ToggleKidDailyReminder.ViewModel) {
        settings = viewModel.settings
    }

    func displayToggleWeeklyParentSummary(_ viewModel: SettingsModels.ToggleWeeklyParentSummary.ViewModel) {
        settings = viewModel.settings
    }

    func displayUpdateHaptics(_ viewModel: SettingsModels.UpdateHaptics.ViewModel) {
        settings = viewModel.settings
    }

    func displayTogglePerformanceMonitoring(_ viewModel: SettingsModels.TogglePerformanceMonitoring.ViewModel) {
        settings = viewModel.settings
        toastMessage = viewModel.toastMessage
        toastIsError = false
    }

    func clearToast() {
        toastMessage = nil
        toastIsError = false
    }

    func clearShareFile() {
        shareFileURL = nil
    }
}
