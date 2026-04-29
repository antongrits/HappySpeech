import Foundation

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

    // MARK: - LoadModelPacks

    enum LoadModelPacks {
        struct Request: Sendable {}
        struct Response: Sendable {
            let asrPacks: [ASRPackState]
            let llmPacks: [LLMPackState]
        }
        struct ViewModel: Sendable {
            let asrItems: [ModelPackRowVM]
            let llmItems: [ModelPackRowVM]
        }
    }

    // MARK: - DownloadModelPack

    enum DownloadModelPack {
        enum Family: Sendable {
            case asr(WhisperKitModelPack)
            case llm(LLMModelPack)
        }
        struct Request: Sendable {
            let family: Family
        }
        struct Response: Sendable {
            let success: Bool
            let identifier: String
            let errorMessage: String?
        }
        struct ViewModel: Sendable {
            let toastMessage: String
            let toastIsError: Bool
        }
    }

    // MARK: - DeleteModelPack

    enum DeleteModelPack {
        struct Request: Sendable {
            let family: DownloadModelPack.Family
        }
        struct Response: Sendable {
            let success: Bool
            let identifier: String
            let errorMessage: String?
        }
        struct ViewModel: Sendable {
            let toastMessage: String
            let toastIsError: Bool
        }
    }

    // MARK: - DownloadProgress

    enum DownloadProgress {
        struct Response: Sendable {
            let identifier: String
            let progress: Double         // 0.0–1.0
            let bytesDownloaded: Int64
            let totalBytes: Int64
            let isFinished: Bool
            let isFailed: Bool
            let errorMessage: String?
        }
        struct ViewModel: Sendable {
            let identifier: String
            let progress: Double
            let progressLine: String     // «12.3 МБ / 150 МБ»
            let isFinished: Bool
            let isFailed: Bool
        }
    }

    // MARK: - LoadLicenses

    enum LoadLicenses {
        struct Request: Sendable {}
        struct Response: Sendable {
            let licenses: [OpenSourceLicense]
        }
        struct ViewModel: Sendable {
            let licenses: [OpenSourceLicenseVM]
        }
    }

    // MARK: - Export GDPR (Share sheet)

    enum ExportShare {
        struct Request: Sendable {
            let userId: String
        }
        struct Response: Sendable {
            let success: Bool
            let fileURL: URL?
            let errorMessage: String?
        }
        struct ViewModel: Sendable {
            let fileURL: URL?
            let toastMessage: String
            let toastIsError: Bool
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

    // MARK: - L9: ToggleKidDailyReminder

    enum ToggleKidDailyReminder {
        struct Request: Sendable {
            let enabled: Bool
        }
        struct Response: Sendable {
            let settings: AppSettings
        }
        struct ViewModel: Sendable {
            let settings: AppSettings
        }
    }

    // MARK: - L9: ToggleWeeklyParentSummary

    enum ToggleWeeklyParentSummary {
        struct Request: Sendable {
            let enabled: Bool
        }
        struct Response: Sendable {
            let settings: AppSettings
        }
        struct ViewModel: Sendable {
            let settings: AppSettings
        }
    }
}

// MARK: - Model packs domain types

/// Состояние ASR-пака (WhisperKit) для UI.
struct ASRPackState: Sendable, Equatable {
    let pack: WhisperKitModelPack
    let isInstalled: Bool
    let isActive: Bool
    let isDownloading: Bool
    let progress: Double
}

/// Состояние LLM-пака (Qwen) для UI.
struct LLMPackState: Sendable, Equatable {
    let pack: LLMModelPack
    let isInstalled: Bool
    let isInUse: Bool
    let isDownloading: Bool
    let progress: Double
}

/// ViewModel строки пака для отображения в списке.
struct ModelPackRowVM: Sendable, Equatable, Identifiable {
    let id: String                // "whisper.tiny" / "llm.qwen15b"
    let title: String             // «Whisper tiny»
    let subtitle: String          // «150 МБ · быстрый, базовое качество»
    let sizeText: String          // «~150 МБ»
    let isInstalled: Bool
    let isActive: Bool            // активный пак (используется сейчас)
    let isDownloading: Bool
    let progress: Double          // 0.0–1.0
    let canDelete: Bool
    let actionTitle: String       // «Скачать» / «Удалить» / «Активный»
}

/// Один пункт в списке «Лицензии открытого ПО».
struct OpenSourceLicense: Sendable, Equatable, Identifiable {
    let id: String                 // package name
    let name: String
    let licenseType: String        // «MIT», «Apache 2.0»
    let url: String?
    let bodyText: String           // полный текст лицензии
}

/// ViewModel для отображения лицензии в списке.
struct OpenSourceLicenseVM: Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let subtitle: String           // «MIT · github.com/...»
    let url: URL?
    let bodyText: String
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
    /// L9: ежедневное напоминание ребёнку в 17:00
    var kidDailyReminderEnabled: Bool
    /// L9: еженедельный итог для родителя в воскресенье 19:00
    var weeklyParentSummaryEnabled: Bool

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
            specialistConnected: false,
            kidDailyReminderEnabled: true,
            weeklyParentSummaryEnabled: true
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
    static let childName                  = "hs.settings.childName"
    static let childAge                   = "hs.settings.childAge"
    static let childAvatar                = "hs.settings.childAvatar"
    static let notificationsEnabled       = "hs.settings.notificationsEnabled"
    static let reminderTime               = "hs.settings.reminderTime"
    static let audioQuality               = "hs.settings.audioQuality"
    static let autoDownload               = "hs.settings.autoDownload"
    static let specialistCode             = "hs.settings.specialistCode"
    static let specialistConnected        = "hs.settings.specialistConnected"
    /// L9
    static let kidDailyReminderEnabled    = "hs.settings.kidDailyReminderEnabled"
    static let weeklyParentSummaryEnabled = "hs.settings.weeklyParentSummaryEnabled"
}
