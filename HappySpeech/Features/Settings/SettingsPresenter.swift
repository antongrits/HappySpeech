import Foundation
import OSLog

// MARK: - SettingsPresentationLogic

@MainActor
protocol SettingsPresentationLogic: AnyObject {
    func presentLoadSettings(_ response: SettingsModels.LoadSettings.Response)
    func presentUpdateTheme(_ response: SettingsModels.UpdateTheme.Response)
    func presentUpdateProfile(_ response: SettingsModels.UpdateProfile.Response)
    func presentToggleNotifications(_ response: SettingsModels.ToggleNotifications.Response)
    func presentUpdateContent(_ response: SettingsModels.UpdateContent.Response)
    func presentExportData(_ response: SettingsModels.ExportData.Response)
    func presentClearCache(_ response: SettingsModels.ClearCache.Response)
    func presentConnectSpecialist(_ response: SettingsModels.ConnectSpecialist.Response)
    func presentFailure(_ response: SettingsModels.Failure.Response)
}

// MARK: - SettingsPresenter

/// Преобразует Response → ViewModel + локализованные toast-строки и форматирование.
@MainActor
final class SettingsPresenter: SettingsPresentationLogic {

    weak var display: (any SettingsDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SettingsPresenter")

    // MARK: - PresentationLogic

    func presentLoadSettings(_ response: SettingsModels.LoadSettings.Response) {
        let versionLine = String(
            format: String(localized: "settings.about.versionPattern"),
            response.appVersion,
            response.buildNumber
        )
        let viewModel = SettingsModels.LoadSettings.ViewModel(
            settings: response.settings,
            appVersionLine: versionLine,
            availableAvatars: ["🦊", "🐰", "🦁", "🐼", "🦉", "🐢"],
            availableAges: Array(3...12)
        )
        display?.displayLoadSettings(viewModel)
    }

    func presentUpdateTheme(_ response: SettingsModels.UpdateTheme.Response) {
        let toast = String(
            format: String(localized: "settings.theme.toastPattern"),
            response.settings.theme.displayName
        )
        display?.displayUpdateTheme(.init(settings: response.settings, toastMessage: toast))
    }

    func presentUpdateProfile(_ response: SettingsModels.UpdateProfile.Response) {
        display?.displayUpdateProfile(.init(
            settings: response.settings,
            toastMessage: String(localized: "settings.profile.toast.updated")
        ))
    }

    func presentToggleNotifications(_ response: SettingsModels.ToggleNotifications.Response) {
        let isError: Bool
        let message: String
        if !response.permissionGranted {
            isError = true
            message = String(localized: "settings.notifications.toast.permissionDenied")
        } else if response.settings.notificationsEnabled {
            isError = false
            let timeStr = formatReminderTime(response.settings.reminderTime)
            message = String(
                format: String(localized: "settings.notifications.toast.enabled"),
                timeStr
            )
        } else {
            isError = false
            message = String(localized: "settings.notifications.toast.disabled")
        }
        display?.displayToggleNotifications(.init(
            settings: response.settings,
            toastMessage: message,
            toastIsError: isError
        ))
    }

    func presentUpdateContent(_ response: SettingsModels.UpdateContent.Response) {
        display?.displayUpdateContent(.init(
            settings: response.settings,
            toastMessage: String(localized: "settings.content.toast.updated")
        ))
    }

    func presentExportData(_ response: SettingsModels.ExportData.Response) {
        if response.success, let fileName = response.fileName {
            let message = String(
                format: String(localized: "settings.export.toast.success"),
                fileName
            )
            display?.displayExportData(.init(toastMessage: message, toastIsError: false))
        } else {
            let message = response.errorMessage ?? String(localized: "settings.export.toast.error")
            display?.displayExportData(.init(toastMessage: message, toastIsError: true))
        }
    }

    func presentClearCache(_ response: SettingsModels.ClearCache.Response) {
        let mb = Double(response.bytesFreed) / 1_048_576.0
        let formatted = String(format: "%.1f", mb)
        let message = String(
            format: String(localized: "settings.cache.toast.cleared"),
            formatted
        )
        display?.displayClearCache(.init(toastMessage: message))
    }

    func presentConnectSpecialist(_ response: SettingsModels.ConnectSpecialist.Response) {
        if response.success {
            display?.displayConnectSpecialist(.init(
                toastMessage: String(localized: "settings.specialist.toast.connected"),
                toastIsError: false,
                settings: response.settings
            ))
        } else {
            display?.displayConnectSpecialist(.init(
                toastMessage: response.errorMessage ?? String(localized: "settings.specialist.error.generic"),
                toastIsError: true,
                settings: response.settings
            ))
        }
    }

    func presentFailure(_ response: SettingsModels.Failure.Response) {
        logger.error("failure: \(response.message, privacy: .public)")
        display?.displayFailure(.init(toastMessage: response.message))
    }

    // MARK: - Helpers

    private func formatReminderTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
