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
    func loadModelPacks(_ request: SettingsModels.LoadModelPacks.Request)
    func downloadModelPack(_ request: SettingsModels.DownloadModelPack.Request)
    func deleteModelPack(_ request: SettingsModels.DeleteModelPack.Request)
    func loadLicenses(_ request: SettingsModels.LoadLicenses.Request)
    func exportShare(_ request: SettingsModels.ExportShare.Request)
    /// L9
    func toggleKidDailyReminder(_ request: SettingsModels.ToggleKidDailyReminder.Request)
    func toggleWeeklyParentSummary(_ request: SettingsModels.ToggleWeeklyParentSummary.Request)
    /// T (v12): тактильная отдача
    func updateHaptics(_ request: SettingsModels.UpdateHaptics.Request)
    /// G (v14): Performance Monitoring opt-in (parent only, COPPA-safe)
    func togglePerformanceMonitoring(_ request: SettingsModels.TogglePerformanceMonitoring.Request)
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
    private let hapticService: any HapticService
    private let performanceMonitorService: (any PerformanceMonitorService)?
    private let whisperKitModelManager: (any WhisperKitModelManagerProtocol)?
    private let llmModelManager: (any LLMModelManagerProtocol)?
    private let defaults: UserDefaults
    private let cacheClearWorker: CacheClearWorker
    private let exportWorker: SettingsExportWorker
    private let logger = Logger(subsystem: "ru.happyspeech", category: "Settings")

    // MARK: - State

    private var settings: AppSettings = .default
    private var asrProgress: [WhisperKitModelPack: Double] = [:]

    // MARK: - Init

    init(
        themeManager: ThemeManager,
        notificationService: any NotificationService,
        hapticService: any HapticService,
        sessionRepository: any SessionRepository,
        performanceMonitorService: (any PerformanceMonitorService)? = nil,
        whisperKitModelManager: (any WhisperKitModelManagerProtocol)? = nil,
        llmModelManager: (any LLMModelManagerProtocol)? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.themeManager = themeManager
        self.notificationService = notificationService
        self.hapticService = hapticService
        self.performanceMonitorService = performanceMonitorService
        self.whisperKitModelManager = whisperKitModelManager
        self.llmModelManager = llmModelManager
        self.defaults = defaults
        self.cacheClearWorker = CacheClearWorker()
        self.exportWorker = SettingsExportWorker(
            sessionRepository: sessionRepository,
            exportService: SpecialistExportServiceLive()
        )
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
        Task { @MainActor [weak self] in
            guard let self else { return }
            logger.info("exportData format=\(request.format.rawValue, privacy: .public)")
            // E.2 — Performance trace: specialist export (parent circuit, COPPA-safe).
            let exportTrace = performanceMonitorService?.trace(name: "specialist_export_trace")
            exportTrace?.start()
            presenter?.presentLoadSettings(.init(
                settings: settings,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
            ))
            do {
                let url: URL
                switch request.format {
                case .pdf:
                    url = try await exportWorker.exportPDF(childId: request.childId)
                case .csv:
                    url = try await exportWorker.exportCSV(childId: request.childId)
                case .json:
                    url = try await exportWorker.exportJSON(childId: request.childId, settings: settings)
                }
                logger.info("exportData success url=\(url.lastPathComponent, privacy: .public)")
                exportTrace?.stop()
                presenter?.presentExportData(.init(
                    success: true,
                    fileURL: url,
                    format: request.format,
                    errorMessage: nil
                ))
            } catch {
                exportTrace?.stop()
                logger.error("exportData failed: \(error.localizedDescription, privacy: .public)")
                presenter?.presentExportData(.init(
                    success: false,
                    fileURL: nil,
                    format: request.format,
                    errorMessage: error.localizedDescription
                ))
            }
        }
    }

    func clearCache(_ request: SettingsModels.ClearCache.Request) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            logger.info("clearCache requested")
            let bytesFreed = await cacheClearWorker.clearAll()
            logger.info("clearCache done bytesFreed=\(bytesFreed, privacy: .public)")
            presenter?.presentClearCache(.init(bytesFreed: bytesFreed))
        }
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
            // Block D v16 migration: эмодзи (legacy) → illustrationName.
            // Если в storage эмодзи (есть символ за пределами ASCII букв/цифр/_),
            // считаем legacy и используем default.
            let isLegacyEmoji = !avatar.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
            settings.childAvatar = isLegacyEmoji ? AppSettings.default.childAvatar : avatar
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

        if defaults.object(forKey: SettingsKey.kidDailyReminderEnabled) != nil {
            settings.kidDailyReminderEnabled = defaults.bool(forKey: SettingsKey.kidDailyReminderEnabled)
        }
        if defaults.object(forKey: SettingsKey.weeklyParentSummaryEnabled) != nil {
            settings.weeklyParentSummaryEnabled = defaults.bool(forKey: SettingsKey.weeklyParentSummaryEnabled)
        }

        if defaults.object(forKey: SettingsKey.hapticsLevel) != nil {
            let scale = defaults.double(forKey: SettingsKey.hapticsLevel)
            settings.hapticsLevel = HapticIntensityLevel.from(scale: scale)
        }

        if defaults.object(forKey: SettingsKey.performanceMonitoringEnabled) != nil {
            settings.performanceMonitoringEnabled = defaults.bool(forKey: SettingsKey.performanceMonitoringEnabled)
        }

        return settings
    }

    // MARK: - T (v12): Haptics level

    func updateHaptics(_ request: SettingsModels.UpdateHaptics.Request) {
        settings.hapticsLevel = request.level
        defaults.set(request.level.scale, forKey: SettingsKey.hapticsLevel)
        hapticService.setIntensityScale(request.level.scale)
        logger.info("haptics → \(request.level.rawValue, privacy: .public)")
        presenter?.presentUpdateHaptics(.init(settings: settings))
    }

    // MARK: - L9: Kid daily reminder + Weekly parent summary toggles

    func toggleKidDailyReminder(_ request: SettingsModels.ToggleKidDailyReminder.Request) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            settings.kidDailyReminderEnabled = request.enabled
            defaults.set(request.enabled, forKey: SettingsKey.kidDailyReminderEnabled)

            if request.enabled {
                await notificationService.scheduleDailyKidReminder(childName: settings.childName)
            } else {
                await notificationService.cancelDailyKidReminder(childName: settings.childName)
            }
            logger.info("kidDailyReminder toggled → \(request.enabled, privacy: .public)")
            presenter?.presentToggleKidDailyReminder(.init(settings: settings))
        }
    }

    func toggleWeeklyParentSummary(_ request: SettingsModels.ToggleWeeklyParentSummary.Request) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            settings.weeklyParentSummaryEnabled = request.enabled
            defaults.set(request.enabled, forKey: SettingsKey.weeklyParentSummaryEnabled)

            if request.enabled {
                await notificationService.scheduleWeeklyParentSummary(achievementsCount: 0, streakDays: 0)
            } else {
                await notificationService.cancelWeeklyParentSummary()
            }
            logger.info("weeklyParentSummary toggled → \(request.enabled, privacy: .public)")
            presenter?.presentToggleWeeklyParentSummary(.init(settings: settings))
        }
    }

    // MARK: - G (v14): Performance Monitoring opt-in

    func togglePerformanceMonitoring(_ request: SettingsModels.TogglePerformanceMonitoring.Request) {
        settings.performanceMonitoringEnabled = request.enabled
        defaults.set(request.enabled, forKey: SettingsKey.performanceMonitoringEnabled)
        performanceMonitorService?.setEnabled(request.enabled)
        logger.info("performanceMonitoring toggled → \(request.enabled, privacy: .public)")
        presenter?.presentTogglePerformanceMonitoring(.init(settings: settings))
    }

    // MARK: - Model packs

    func loadModelPacks(_ request: SettingsModels.LoadModelPacks.Request) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let asrStates = await collectASRPackStates()
            let llmStates = await collectLLMPackStates()
            presenter?.presentLoadModelPacks(.init(
                asrPacks: asrStates,
                llmPacks: llmStates
            ))
        }
    }

    func downloadModelPack(_ request: SettingsModels.DownloadModelPack.Request) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch request.family {
            case .asr(let pack):
                await downloadASRPack(pack)
            case .llm(let pack):
                await downloadLLMPack(pack)
            }
        }
    }

    func deleteModelPack(_ request: SettingsModels.DeleteModelPack.Request) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch request.family {
            case .asr(let pack):
                await deleteASRPack(pack)
            case .llm(let pack):
                await deleteLLMPack(pack)
            }
        }
    }

    func loadLicenses(_ request: SettingsModels.LoadLicenses.Request) {
        let licenses: [OpenSourceLicense] = [
            OpenSourceLicense(
                id: "whisperkit",
                name: "WhisperKit",
                licenseType: "MIT",
                url: "https://github.com/argmaxinc/WhisperKit",
                bodyText: String(localized: "settings.licenses.body.whisperkit")
            ),
            OpenSourceLicense(
                id: "realm-swift",
                name: "Realm Swift",
                licenseType: "Apache 2.0",
                url: "https://github.com/realm/realm-swift",
                bodyText: String(localized: "settings.licenses.body.realm")
            ),
            OpenSourceLicense(
                id: "firebase-ios-sdk",
                name: "Firebase iOS SDK",
                licenseType: "Apache 2.0",
                url: "https://github.com/firebase/firebase-ios-sdk",
                bodyText: String(localized: "settings.licenses.body.firebase")
            ),
            OpenSourceLicense(
                id: "swift-snapshot-testing",
                name: "swift-snapshot-testing",
                licenseType: "MIT",
                url: "https://github.com/pointfreeco/swift-snapshot-testing",
                bodyText: String(localized: "settings.licenses.body.snapshot")
            ),
            OpenSourceLicense(
                id: "qwen2.5",
                name: "Qwen2.5-1.5B",
                licenseType: "Apache 2.0",
                url: "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct",
                bodyText: String(localized: "settings.licenses.body.qwen")
            ),
            OpenSourceLicense(
                id: "silero-vad",
                name: "Silero VAD",
                licenseType: "MIT",
                url: "https://github.com/snakers4/silero-vad",
                bodyText: String(localized: "settings.licenses.body.silero")
            )
        ]
        presenter?.presentLoadLicenses(.init(licenses: licenses))
    }

    func exportShare(_ request: SettingsModels.ExportShare.Request) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let payload = makeExportPayload(userId: request.userId)
                let data = try JSONEncoder().encode(payload)
                let timestamp = Int(Date().timeIntervalSince1970)
                let fileName = "happyspeech-export-\(timestamp).json"
                let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try data.write(to: tmpURL, options: .atomic)
                logger.info("export file written \(fileName, privacy: .public)")
                presenter?.presentExportShare(.init(
                    success: true,
                    fileURL: tmpURL,
                    errorMessage: nil
                ))
            } catch {
                logger.error("export failed: \(error.localizedDescription, privacy: .public)")
                presenter?.presentExportShare(.init(
                    success: false,
                    fileURL: nil,
                    errorMessage: error.localizedDescription
                ))
            }
        }
    }

    // MARK: - Model packs helpers

    private func collectASRPackStates() async -> [ASRPackState] {
        guard let manager = whisperKitModelManager else {
            // Деградация без manager — возвращаем минимальный набор для UI.
            return WhisperKitModelPack.allCases.map { pack in
                ASRPackState(pack: pack, isInstalled: false, isActive: false, isDownloading: false, progress: 0)
            }
        }
        let installed = await manager.installedPacks()
        let active = await manager.currentlyInstalledPack()
        let installedSet = Set(installed)
        return WhisperKitModelPack.allCases.map { pack in
            ASRPackState(
                pack: pack,
                isInstalled: installedSet.contains(pack),
                isActive: active == pack,
                isDownloading: asrProgress[pack] != nil,
                progress: asrProgress[pack] ?? 0
            )
        }
    }

    private func collectLLMPackStates() async -> [LLMPackState] {
        guard let manager = llmModelManager else {
            return LLMModelPack.allCases.map { pack in
                LLMPackState(pack: pack, isInstalled: false, isInUse: false, isDownloading: false, progress: 0)
            }
        }
        var states: [LLMPackState] = []
        for pack in LLMModelPack.allCases {
            let installed = await manager.isModelInstalled(pack)
            let inUse = await manager.isCurrentlyInUse(pack)
            // Модель встроена в бандл — операций загрузки нет.
            states.append(LLMPackState(
                pack: pack,
                isInstalled: installed,
                isInUse: inUse,
                isDownloading: false,
                progress: 0
            ))
        }
        return states
    }

    private func downloadASRPack(_ pack: WhisperKitModelPack) async {
        guard let manager = whisperKitModelManager else {
            presenter?.presentDownloadModelPack(.init(
                success: false,
                identifier: "whisper.\(pack.rawValue)",
                errorMessage: String(localized: "settings.models.error.unavailable")
            ))
            return
        }
        asrProgress[pack] = 0
        logger.info("ASR pack download start: \(pack.rawValue, privacy: .public)")
        do {
            try await manager.download(pack: pack)
            asrProgress[pack] = nil
            logger.info("ASR pack downloaded: \(pack.rawValue, privacy: .public)")
            presenter?.presentDownloadModelPack(.init(
                success: true,
                identifier: "whisper.\(pack.rawValue)",
                errorMessage: nil
            ))
            // Обновим список паков.
            loadModelPacks(.init())
        } catch {
            asrProgress[pack] = nil
            logger.error("ASR download failed: \(error.localizedDescription, privacy: .public)")
            presenter?.presentDownloadModelPack(.init(
                success: false,
                identifier: "whisper.\(pack.rawValue)",
                errorMessage: error.localizedDescription
            ))
        }
    }

    /// LLM-модель поставляется внутри бандла приложения — отдельной загрузки нет.
    /// Метод подтверждает, что модель уже встроена и доступна для работы.
    private func downloadLLMPack(_ pack: LLMModelPack) async {
        logger.info("LLM pack is bundled, no download needed: \(pack.rawValue, privacy: .public)")
        presenter?.presentDownloadModelPack(.init(
            success: true,
            identifier: "llm.\(pack.rawValue)",
            errorMessage: nil
        ))
        loadModelPacks(.init())
    }

    private func deleteASRPack(_ pack: WhisperKitModelPack) async {
        guard let manager = whisperKitModelManager else {
            presenter?.presentDeleteModelPack(.init(
                success: false,
                identifier: "whisper.\(pack.rawValue)",
                errorMessage: String(localized: "settings.models.error.unavailable")
            ))
            return
        }
        do {
            try await manager.deletePack(pack)
            logger.info("ASR pack deleted: \(pack.rawValue, privacy: .public)")
            presenter?.presentDeleteModelPack(.init(
                success: true,
                identifier: "whisper.\(pack.rawValue)",
                errorMessage: nil
            ))
            loadModelPacks(.init())
        } catch {
            logger.error("ASR delete failed: \(error.localizedDescription, privacy: .public)")
            presenter?.presentDeleteModelPack(.init(
                success: false,
                identifier: "whisper.\(pack.rawValue)",
                errorMessage: error.localizedDescription
            ))
        }
    }

    /// LLM-модель встроена в бандл приложения и не может быть удалена.
    private func deleteLLMPack(_ pack: LLMModelPack) async {
        logger.info("LLM pack is bundled, cannot be deleted: \(pack.rawValue, privacy: .public)")
        presenter?.presentDeleteModelPack(.init(
            success: false,
            identifier: "llm.\(pack.rawValue)",
            errorMessage: String(localized: "settings.models.error.bundled")
        ))
    }

    // MARK: - Export helpers

    private struct ExportPayload: Codable {
        let exportedAt: Date
        let userId: String
        let appVersion: String
        let buildNumber: String
        let settings: ExportSettings
    }

    private struct ExportSettings: Codable {
        let theme: String
        let childName: String
        let childAge: Int
        let childAvatar: String
        let notificationsEnabled: Bool
        let audioQuality: String
        let autoDownload: Bool
        let specialistConnected: Bool
    }

    private func makeExportPayload(userId: String) -> ExportPayload {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info["CFBundleVersion"] as? String ?? "1"
        return ExportPayload(
            exportedAt: Date(),
            userId: userId,
            appVersion: version,
            buildNumber: build,
            settings: ExportSettings(
                theme: settings.theme.rawValue,
                childName: settings.childName,
                childAge: settings.childAge,
                childAvatar: settings.childAvatar,
                notificationsEnabled: settings.notificationsEnabled,
                audioQuality: settings.audioQuality.rawValue,
                autoDownload: settings.autoDownload,
                specialistConnected: settings.specialistConnected
            )
        )
    }
}
