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
    func presentLoadModelPacks(_ response: SettingsModels.LoadModelPacks.Response)
    func presentDownloadModelPack(_ response: SettingsModels.DownloadModelPack.Response)
    func presentDeleteModelPack(_ response: SettingsModels.DeleteModelPack.Response)
    func presentLoadLicenses(_ response: SettingsModels.LoadLicenses.Response)
    func presentExportShare(_ response: SettingsModels.ExportShare.Response)
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

    func presentLoadModelPacks(_ response: SettingsModels.LoadModelPacks.Response) {
        let asrItems = response.asrPacks.map { state -> ModelPackRowVM in
            let title = state.pack.displayName
            let subtitle = subtitleASR(for: state.pack)
            let size = formatBytes(state.pack.sizeBytes)
            let action: String
            if state.isActive {
                action = String(localized: "settings.models.status.active")
            } else if state.isInstalled {
                action = String(localized: "settings.models.action.delete")
            } else if state.isDownloading {
                action = String(localized: "settings.models.status.downloading")
            } else {
                action = String(localized: "settings.models.action.download")
            }
            return ModelPackRowVM(
                id: "whisper.\(state.pack.rawValue)",
                title: title,
                subtitle: subtitle,
                sizeText: size,
                isInstalled: state.isInstalled,
                isActive: state.isActive,
                isDownloading: state.isDownloading,
                progress: state.progress,
                canDelete: state.isInstalled && !state.isActive,
                actionTitle: action
            )
        }
        let llmItems = response.llmPacks.map { state -> ModelPackRowVM in
            let title = state.pack.displayName
            let subtitle = state.pack.tierDescription
            let size = formatBytes(state.pack.sizeBytes)
            let action: String
            if state.isInUse {
                action = String(localized: "settings.models.status.active")
            } else if state.isInstalled {
                action = String(localized: "settings.models.action.delete")
            } else if state.isDownloading {
                action = String(localized: "settings.models.status.downloading")
            } else {
                action = String(localized: "settings.models.action.download")
            }
            return ModelPackRowVM(
                id: "llm.\(state.pack.rawValue)",
                title: title,
                subtitle: subtitle,
                sizeText: size,
                isInstalled: state.isInstalled,
                isActive: state.isInUse,
                isDownloading: state.isDownloading,
                progress: state.progress,
                canDelete: state.isInstalled && !state.isInUse,
                actionTitle: action
            )
        }
        display?.displayLoadModelPacks(.init(asrItems: asrItems, llmItems: llmItems))
    }

    func presentDownloadModelPack(_ response: SettingsModels.DownloadModelPack.Response) {
        let message: String
        if response.success {
            message = String(localized: "settings.models.toast.downloaded")
        } else {
            message = response.errorMessage ?? String(localized: "settings.models.toast.downloadFailed")
        }
        display?.displayDownloadModelPack(.init(
            toastMessage: message,
            toastIsError: !response.success
        ))
    }

    func presentDeleteModelPack(_ response: SettingsModels.DeleteModelPack.Response) {
        let message: String
        if response.success {
            message = String(localized: "settings.models.toast.deleted")
        } else {
            message = response.errorMessage ?? String(localized: "settings.models.toast.deleteFailed")
        }
        display?.displayDeleteModelPack(.init(
            toastMessage: message,
            toastIsError: !response.success
        ))
    }

    func presentLoadLicenses(_ response: SettingsModels.LoadLicenses.Response) {
        let items = response.licenses.map { license -> OpenSourceLicenseVM in
            let subtitle: String
            if let url = license.url, let host = URL(string: url)?.host {
                subtitle = "\(license.licenseType) · \(host)"
            } else {
                subtitle = license.licenseType
            }
            return OpenSourceLicenseVM(
                id: license.id,
                title: license.name,
                subtitle: subtitle,
                url: license.url.flatMap(URL.init(string:)),
                bodyText: license.bodyText
            )
        }
        display?.displayLoadLicenses(.init(licenses: items))
    }

    func presentExportShare(_ response: SettingsModels.ExportShare.Response) {
        if response.success, let url = response.fileURL {
            display?.displayExportShare(.init(
                fileURL: url,
                toastMessage: String(localized: "settings.export.toast.shareReady"),
                toastIsError: false
            ))
        } else {
            let message = response.errorMessage ?? String(localized: "settings.export.toast.error")
            display?.displayExportShare(.init(
                fileURL: nil,
                toastMessage: message,
                toastIsError: true
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

    private func formatBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576.0
        if mb >= 1024 {
            return String(format: "%.1f ГБ", mb / 1024.0)
        }
        return String(format: "%.0f МБ", mb)
    }

    private func subtitleASR(for pack: WhisperKitModelPack) -> String {
        switch pack {
        case .tiny:  return String(localized: "settings.models.whisper.tiny.subtitle")
        case .base:  return String(localized: "settings.models.whisper.base.subtitle")
        case .small: return String(localized: "settings.models.whisper.small.subtitle")
        }
    }
}
