import Foundation

// MARK: - Settings VIP Models
//
// Доменные модели + transport-слои Request / Response / ViewModel.
// Контур: parent. Секции — оформление, профиль, уведомления, контент,
// данные, специалист, о приложении. Состояние хранится в `AppSettings`,
// часть полей синхронизируется с `ThemeManager` / `UserDefaults`.
//
// Модели речи (ASR/LLM) встроены в бандл и заранее настроены на лучшее
// качество — экран выбора/закачки моделей удалён намеренно.

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
        struct Request: Sendable {
            let format: ExportFormat
            let childId: String
        }
        struct Response: Sendable {
            let success: Bool
            let fileURL: URL?
            let format: ExportFormat
            let errorMessage: String?
        }
        struct ViewModel: Sendable {
            let fileURL: URL?
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

    // MARK: - T (v12): UpdateHaptics

    enum UpdateHaptics {
        struct Request: Sendable {
            let level: HapticIntensityLevel
        }
        struct Response: Sendable {
            let settings: AppSettings
        }
        struct ViewModel: Sendable {
            let settings: AppSettings
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

    // MARK: - A-08: ToggleCalmMode

    enum ToggleCalmMode {
        struct Request: Sendable {
            let enabled: Bool
        }
        struct Response: Sendable {
            let settings: AppSettings
        }
        struct ViewModel: Sendable {
            let settings: AppSettings
            let toastMessage: String
        }
    }

    // MARK: - G v14: TogglePerformanceMonitoring

    enum TogglePerformanceMonitoring {
        struct Request: Sendable {
            let enabled: Bool
        }
        struct Response: Sendable {
            let settings: AppSettings
        }
        struct ViewModel: Sendable {
            let settings: AppSettings
            let toastMessage: String
        }
    }
}

// MARK: - Open-source licenses domain types

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
    /// T (v12): уровень тактильной отдачи
    var hapticsLevel: HapticIntensityLevel
    /// G (v14): анонимная аналитика производительности (только parent, COPPA-safe, OFF by default)
    var performanceMonitoringEnabled: Bool
    /// A-08: «Спокойный режим» — сниженная сенсорная стимуляция детского контура
    /// (для детей, чувствительных к ярким анимациям и звукам). OFF by default.
    var calmModeEnabled: Bool

    static var `default`: AppSettings {
        var components = DateComponents()
        components.hour = 18
        components.minute = 0
        let defaultTime = Calendar.current.date(from: components) ?? Date()

        return AppSettings(
            theme: .system,
            childName: String(localized: "settings.profile.defaultName"),
            childAge: 6,
            childAvatar: "word_fox",
            notificationsEnabled: true,
            reminderTime: defaultTime,
            audioQuality: .standard,
            autoDownload: true,
            specialistCode: "",
            specialistConnected: false,
            kidDailyReminderEnabled: true,
            weeklyParentSummaryEnabled: true,
            hapticsLevel: .full,
            performanceMonitoringEnabled: false,
            calmModeEnabled: false
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

// MARK: - ExportFormat

/// Формат экспорта данных пользователя.
enum ExportFormat: String, Sendable, CaseIterable {
    case pdf
    case csv
    case json
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
    /// T (v12): тактильная отдача
    static let hapticsLevel               = "Haptics.intensity"
    /// G (v14): анонимный мониторинг производительности (parent only, COPPA-safe)
    static let performanceMonitoringEnabled = "hs.settings.performanceMonitoringEnabled"
    /// A-08: «Спокойный режим». Совпадает с ключом `CalmModeManager` — один источник истины.
    static let calmModeEnabled = "hs.settings.calmModeEnabled"
}
