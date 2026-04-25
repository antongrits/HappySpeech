import Foundation
import SwiftUI

// MARK: - Settings VIP Models
//
// Доменные модели + transport-слои Request / Response / ViewModel.
// Контур: parent. 7 секций — оформление, профиль, уведомления, контент,
// данные, специалист, о приложении. Состояние хранится в `AppSettings`,
// часть полей синхронизируется с `ThemeManager` / `UserDefaults`.

enum SettingsModels {

    // MARK: - LoadSettings

    enum LoadSettings {
        struct Request: Sendable {}
        struct Response: Sendable {
            let settings: AppSettings
            let appVersion: String
            let buildNumber: String
        }
        struct ViewModel: Sendable {
            let settings: AppSettings
            let appVersionLine: String
            let availableAvatars: [String]
            let availableAges: [Int]
        }
    }

    // MARK: - UpdateTheme

    enum UpdateTheme {
        struct Request: Sendable {
            let theme: AppTheme
        }
        struct Response: Sendable {
            let settings: AppSettings
        }
        struct ViewModel: Sendable {
            let settings: AppSettings
            let toastMessage: String
        }
    }

    // MARK: - UpdateProfile

    enum UpdateProfile {
        struct Request: Sendable {
            let name: String?
            let age: Int?
            let avatar: String?
        }
        struct Response: Sendable {
            let settings: AppSettings
        }
        struct ViewModel: Sendable {
            let settings: AppSettings
            let toastMessage: String
        }
    }

    // MARK: - ToggleNotifications

    enum ToggleNotifications {
        struct Request: Sendable {
            let enabled: Bool
            let reminderTime: Date
        }
        struct Response: Sendable {
            let settings: AppSettings
            let permissionGranted: Bool
        }
        struct ViewModel: Sendable {
            let settings: AppSettings
            let toastMessage: String
            let toastIsError: Bool
        }
    }

    // MARK: - UpdateContent

    enum UpdateContent {
        struct Request: Sendable {
            let autoDownload: Bool?
            let audioQuality: AudioQuality?
        }
        struct Response: Sendable {
            let settings: AppSettings
        }
        struct ViewModel: Sendable {
            let settings: AppSettings
            let toastMessage: String
        }
    }

    // MARK: - ExportData

    enum ExportData {
        struct Request: Sendable {}
        struct Response: Sendable {
            let success: Bool
            let fileName: String?
            let errorMessage: String?
        }
        struct ViewModel: Sendable {
            let toastMessage: String
            let toastIsError: Bool
        }
    }

    // MARK: - ClearCache

    enum ClearCache {
        struct Request: Sendable {}
        struct Response: Sendable {
            let bytesFreed: Int
        }
        struct ViewModel: Sendable {
            let toastMessage: String
        }
    }

    // MARK: - ConnectSpecialist

    enum ConnectSpecialist {
        struct Request: Sendable {
            let code: String
        }
        struct Response: Sendable {
            let success: Bool
            let settings: AppSettings
            let errorMessage: String?
        }
        struct ViewModel: Sendable {
            let toastMessage: String
            let toastIsError: Bool
            let settings: AppSettings
        }
    }

    // MARK: - Failure

    enum Failure {
        struct Response: Sendable {
            let message: String
        }
        struct ViewModel: Sendable {
            let toastMessage: String
        }
    }
}

// MARK: - Domain types

/// Корневая модель пользовательских настроек. Часть полей хранится в
/// `UserDefaults`, часть синхронизируется с `ThemeManager`. На M8 будет
/// добавлено сохранение в Realm и Firestore (parent profile doc).
struct AppSettings: Sendable, Equatable {
    var theme: AppTheme
    var childName: String
    var childAge: Int
    var childAvatar: String
    var notificationsEnabled: Bool
    var reminderTime: Date
    var audioQuality: AudioQuality
    var autoDownload: Bool
    var specialistCode: String
    var specialistConnected: Bool

    static var `default`: AppSettings {
        var components = DateComponents()
        components.hour = 18
        components.minute = 0
        let defaultTime = Calendar.current.date(from: components) ?? Date()

        return AppSettings(
            theme: .system,
            childName: String(localized: "settings.profile.defaultName"),
            childAge: 6,
            childAvatar: "🦊",
            notificationsEnabled: true,
            reminderTime: defaultTime,
            audioQuality: .standard,
            autoDownload: true,
            specialistCode: "",
            specialistConnected: false
        )
    }
}

/// Качество загружаемого аудио (контент-паки).
enum AudioQuality: String, Sendable, CaseIterable, Equatable {
    case standard
    case high

    var displayName: String {
        switch self {
        case .standard: return String(localized: "settings.content.quality.standard")
        case .high:     return String(localized: "settings.content.quality.high")
        }
    }
}

// MARK: - Persistence keys

enum SettingsKey {
    static let childName            = "hs.settings.childName"
    static let childAge             = "hs.settings.childAge"
    static let childAvatar          = "hs.settings.childAvatar"
    static let notificationsEnabled = "hs.settings.notificationsEnabled"
    static let reminderTime         = "hs.settings.reminderTime"
    static let audioQuality         = "hs.settings.audioQuality"
    static let autoDownload         = "hs.settings.autoDownload"
    static let specialistCode       = "hs.settings.specialistCode"
    static let specialistConnected  = "hs.settings.specialistConnected"
}
