import Foundation
import OSLog

// MARK: - SettingsBusinessLogic

@MainActor
protocol SettingsBusinessLogic: AnyObject {
    func loadSettings(_ request: SettingsModels.LoadSettings.Request)
    func updateTheme(_ request: SettingsModels.UpdateTheme.Request)
    func updateProfile(_ request: SettingsModels.UpdateProfile.Request)
    func toggleNotifications(_ request: SettingsModels.ToggleNotifications.Request)
    func updateContent(_ request: SettingsModels.UpdateContent.Request)
    func exportData(_ request: SettingsModels.ExportData.Request)
    func clearCache(_ request: SettingsModels.ClearCache.Request)
    func connectSpecialist(_ request: SettingsModels.ConnectSpecialist.Request)
}

// MARK: - SettingsInteractor

/// Бизнес-логика экрана «Настройки».
///
/// Хранение: `UserDefaults` для большинства полей, `ThemeManager` для темы.
/// На M8 будет добавлено сохранение в Realm и Firestore (parent profile doc).
@MainActor
final class SettingsInteractor: SettingsBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any SettingsPresentationLogic)?

    private let themeManager: ThemeManager
    private let notificationService: any NotificationService
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "ru.happyspeech", category: "Settings")

    // MARK: - State

    private var settings: AppSettings = .default

    // MARK: - Init

    init(
        themeManager: ThemeManager,
        notificationService: any NotificationService,
        defaults: UserDefaults = .standard
    ) {
        self.themeManager = themeManager
        self.notificationService = notificationService
        self.defaults = defaults
    }

    // MARK: - BusinessLogic

    func loadSettings(_ request: SettingsModels.LoadSettings.Request) {
        settings = readFromDefaults()
        // Тема — единственный источник истины ThemeManager.
        settings.theme = themeManager.selectedTheme

        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info["CFBundleVersion"] as? String ?? "1"

        logger.info("loadSettings theme=\(self.settings.theme.rawValue, privacy: .public)")

        let response = SettingsModels.LoadSettings.Response(
            settings: settings,
            appVersion: version,
            buildNumber: build
        )
        presenter?.presentLoadSettings(response)
    }

    func updateTheme(_ request: SettingsModels.UpdateTheme.Request) {
        themeManager.selectedTheme = request.theme
        settings.theme = request.theme
        logger.info("theme → \(request.theme.rawValue, privacy: .public)")
        presenter?.presentUpdateTheme(.init(settings: settings))
    }

    func updateProfile(_ request: SettingsModels.UpdateProfile.Request) {
        if let name = request.name {
            settings.childName = name
            defaults.set(name, forKey: SettingsKey.childName)
        }
        if let age = request.age {
            settings.childAge = age
            defaults.set(age, forKey: SettingsKey.childAge)
        }
        if let avatar = request.avatar {
            settings.childAvatar = avatar
            defaults.set(avatar, forKey: SettingsKey.childAvatar)
        }
        logger.info("profile updated name=\(self.settings.childName, privacy: .private) age=\(self.settings.childAge, privacy: .public)")
        presenter?.presentUpdateProfile(.init(settings: settings))
    }

    func toggleNotifications(_ request: SettingsModels.ToggleNotifications.Request) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            settings.notificationsEnabled = request.enabled
            settings.reminderTime = request.reminderTime
            defaults.set(request.enabled, forKey: SettingsKey.notificationsEnabled)
            defaults.set(request.reminderTime.timeIntervalSince1970, forKey: SettingsKey.reminderTime)

            var permissionGranted = true
            if request.enabled {
                permissionGranted = await notificationService.requestPermission()
                if permissionGranted {
                    let components = Calendar.current.dateComponents([.hour, .minute], from: request.reminderTime)
                    do {
                        try await notificationService.scheduleDailyReminder(
                            at: components.hour ?? 18,
                            minute: components.minute ?? 0
                        )
                        logger.info("daily reminder scheduled")
                    } catch {
                        logger.error("schedule failed: \(error.localizedDescription, privacy: .public)")
                        presenter?.presentToggleNotifications(.init(
                            settings: settings,
                            permissionGranted: false
                        ))
                        return
                    }
                } else {
                    settings.notificationsEnabled = false
                    defaults.set(false, forKey: SettingsKey.notificationsEnabled)
                }
            } else {
                await notificationService.cancelAllReminders()
                logger.info("reminders cancelled")
            }

            presenter?.presentToggleNotifications(.init(
                settings: settings,
                permissionGranted: permissionGranted
            ))
        }
    }

    func updateContent(_ request: SettingsModels.UpdateContent.Request) {
        if let auto = request.autoDownload {
            settings.autoDownload = auto
            defaults.set(auto, forKey: SettingsKey.autoDownload)
        }
        if let quality = request.audioQuality {
            settings.audioQuality = quality
            defaults.set(quality.rawValue, forKey: SettingsKey.audioQuality)
        }
        logger.info("content updated quality=\(self.settings.audioQuality.rawValue, privacy: .public)")
        presenter?.presentUpdateContent(.init(settings: settings))
    }

    func exportData(_ request: SettingsModels.ExportData.Request) {
        // M7.2: stub — на M8 будет интеграция с SpecialistExportService.
        // Эмулируем успешный экспорт.
        logger.info("export requested (stub)")
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "happyspeech-export-\(timestamp).json"
        presenter?.presentExportData(.init(
            success: true,
            fileName: fileName,
            errorMessage: nil
        ))
    }

    func clearCache(_ request: SettingsModels.ClearCache.Request) {
        // M7.2: stub — реальная очистка кэша моделей и аудио будет на M8.
        logger.info("clearCache requested (stub)")
        let bytesFreed = 47_104_000 // ~45 MB — типовой размер аудиокэша.
        presenter?.presentClearCache(.init(bytesFreed: bytesFreed))
    }

    func connectSpecialist(_ request: SettingsModels.ConnectSpecialist.Request) {
        let trimmed = request.code.trimmingCharacters(in: .whitespacesAndNewlines)
        // Валидация: 6 цифр.
        let valid = trimmed.count == 6 && trimmed.allSatisfy(\.isNumber)
        if !valid {
            logger.warning("invalid specialist code length=\(trimmed.count, privacy: .public)")
            presenter?.presentConnectSpecialist(.init(
                success: false,
                settings: settings,
                errorMessage: String(localized: "settings.specialist.error.invalidCode")
            ))
            return
        }

        settings.specialistCode = trimmed
        settings.specialistConnected = true
        defaults.set(trimmed, forKey: SettingsKey.specialistCode)
        defaults.set(true, forKey: SettingsKey.specialistConnected)
        logger.info("specialist connected")

        presenter?.presentConnectSpecialist(.init(
            success: true,
            settings: settings,
            errorMessage: nil
        ))
    }

    // MARK: - Persistence

    private func readFromDefaults() -> AppSettings {
        var settings = AppSettings.default

        if let name = defaults.string(forKey: SettingsKey.childName), !name.isEmpty {
            settings.childName = name
        }
        let age = defaults.integer(forKey: SettingsKey.childAge)
        if age > 0 { settings.childAge = age }

        if let avatar = defaults.string(forKey: SettingsKey.childAvatar), !avatar.isEmpty {
            settings.childAvatar = avatar
        }

        if defaults.object(forKey: SettingsKey.notificationsEnabled) != nil {
            settings.notificationsEnabled = defaults.bool(forKey: SettingsKey.notificationsEnabled)
        }

        let reminderInterval = defaults.double(forKey: SettingsKey.reminderTime)
        if reminderInterval > 0 {
            settings.reminderTime = Date(timeIntervalSince1970: reminderInterval)
        }

        if let qualityRaw = defaults.string(forKey: SettingsKey.audioQuality),
           let quality = AudioQuality(rawValue: qualityRaw) {
            settings.audioQuality = quality
        }

        if defaults.object(forKey: SettingsKey.autoDownload) != nil {
            settings.autoDownload = defaults.bool(forKey: SettingsKey.autoDownload)
        }

        if let code = defaults.string(forKey: SettingsKey.specialistCode) {
            settings.specialistCode = code
        }
        settings.specialistConnected = defaults.bool(forKey: SettingsKey.specialistConnected)

        return settings
    }
}
