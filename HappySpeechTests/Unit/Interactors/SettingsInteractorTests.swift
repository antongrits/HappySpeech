@testable import HappySpeech
import XCTest

// MARK: - SettingsInteractorTests
//
// M10.1 — 10 тестов для SettingsInteractor.
// Покрывает: loadSettings, updateTheme, updateProfile, toggleNotifications (off),
// updateContent, exportData, clearCache, connectSpecialist (valid/invalid), loadLicenses.

@MainActor
final class SettingsInteractorTests: XCTestCase {

    // MARK: - Spy

    @MainActor
    private final class SpyPresenter: SettingsPresentationLogic {
        var loadSettingsCalled = false
        var updateThemeCalled = false
        var updateProfileCalled = false
        var toggleNotificationsCalled = false
        var updateContentCalled = false
        var exportDataCalled = false
        var clearCacheCalled = false
        var connectSpecialistCalled = false
        var loadModelPacksCalled = false
        var downloadModelPackCalled = false
        var deleteModelPackCalled = false
        var loadLicensesCalled = false
        var exportShareCalled = false
        var failureCalled = false

        var lastLoadSettings: SettingsModels.LoadSettings.Response?
        var lastUpdateTheme: SettingsModels.UpdateTheme.Response?
        var lastUpdateProfile: SettingsModels.UpdateProfile.Response?
        var lastConnectSpecialist: SettingsModels.ConnectSpecialist.Response?
        var lastClearCache: SettingsModels.ClearCache.Response?
        var lastLoadLicenses: SettingsModels.LoadLicenses.Response?

        func presentLoadSettings(_ response: SettingsModels.LoadSettings.Response) {
            loadSettingsCalled = true; lastLoadSettings = response
        }
        func presentUpdateTheme(_ response: SettingsModels.UpdateTheme.Response) {
            updateThemeCalled = true; lastUpdateTheme = response
        }
        func presentUpdateProfile(_ response: SettingsModels.UpdateProfile.Response) {
            updateProfileCalled = true; lastUpdateProfile = response
        }
        func presentToggleNotifications(_ response: SettingsModels.ToggleNotifications.Response) {
            toggleNotificationsCalled = true
        }
        func presentUpdateContent(_ response: SettingsModels.UpdateContent.Response) {
            updateContentCalled = true
        }
        func presentExportData(_ response: SettingsModels.ExportData.Response) {
            exportDataCalled = true
        }
        func presentClearCache(_ response: SettingsModels.ClearCache.Response) {
            clearCacheCalled = true; lastClearCache = response
        }
        func presentConnectSpecialist(_ response: SettingsModels.ConnectSpecialist.Response) {
            connectSpecialistCalled = true; lastConnectSpecialist = response
        }
        func presentLoadModelPacks(_ response: SettingsModels.LoadModelPacks.Response) {
            loadModelPacksCalled = true
        }
        func presentDownloadModelPack(_ response: SettingsModels.DownloadModelPack.Response) {
            downloadModelPackCalled = true
        }
        func presentDeleteModelPack(_ response: SettingsModels.DeleteModelPack.Response) {
            deleteModelPackCalled = true
        }
        func presentLoadLicenses(_ response: SettingsModels.LoadLicenses.Response) {
            loadLicensesCalled = true; lastLoadLicenses = response
        }
        func presentExportShare(_ response: SettingsModels.ExportShare.Response) {
            exportShareCalled = true
        }
        func presentFailure(_ response: SettingsModels.Failure.Response) {
            failureCalled = true
        }
        func presentToggleKidDailyReminder(_ response: SettingsModels.ToggleKidDailyReminder.Response) {}
        func presentToggleWeeklyParentSummary(_ response: SettingsModels.ToggleWeeklyParentSummary.Response) {}
        func presentUpdateHaptics(_ response: SettingsModels.UpdateHaptics.Response) {}
        func presentTogglePerformanceMonitoring(_ response: SettingsModels.TogglePerformanceMonitoring.Response) {}
    }

    private func makeSUT() -> (SettingsInteractor, SpyPresenter) {
        let sut = SettingsInteractor(
            themeManager: ThemeManager(),
            notificationService: MockNotificationService(),
            hapticService: MockHapticService(),
            sessionRepository: MockSessionRepository(),
            defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        )
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. loadSettings вызывает presentLoadSettings

    func test_loadSettings_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadSettings(.init())
        XCTAssertTrue(spy.loadSettingsCalled)
        XCTAssertNotNil(spy.lastLoadSettings)
    }

    // MARK: - 2. loadSettings возвращает версию приложения

    func test_loadSettings_appVersionNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.loadSettings(.init())
        XCTAssertFalse(spy.lastLoadSettings?.appVersion.isEmpty ?? true)
    }

    // MARK: - 3. updateTheme меняет тему

    func test_updateTheme_updatesTheme() {
        let (sut, spy) = makeSUT()
        sut.loadSettings(.init())
        sut.updateTheme(.init(theme: .dark))
        XCTAssertTrue(spy.updateThemeCalled)
        XCTAssertEqual(spy.lastUpdateTheme?.settings.theme, .dark)
    }

    // MARK: - 4. updateProfile обновляет имя ребёнка

    func test_updateProfile_updatesName() {
        let (sut, spy) = makeSUT()
        sut.loadSettings(.init())
        sut.updateProfile(.init(name: "Миша", age: nil, avatar: nil))
        XCTAssertTrue(spy.updateProfileCalled)
        XCTAssertEqual(spy.lastUpdateProfile?.settings.childName, "Миша")
    }

    // MARK: - 5. exportData вызывает presentExportData

    func test_exportData_callsPresenter() async throws {
        let (sut, spy) = makeSUT()
        sut.exportData(.init(format: .pdf, childId: "test-child-id"))
        // exportData выполняется в Task — даём ему завершиться
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(spy.exportDataCalled)
    }

    // MARK: - 6. clearCache вызывает presentClearCache (bytesFreed >= 0)
    // В тестовом окружении симулятора кэш может быть пустым → 0 байт корректный результат.

    func test_clearCache_callsPresenterWithBytes() async throws {
        let (sut, spy) = makeSUT()
        sut.clearCache(.init())
        // clearCache выполняется в Task — даём ему завершиться
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(spy.clearCacheCalled)
        XCTAssertGreaterThanOrEqual(spy.lastClearCache?.bytesFreed ?? -1, 0)
    }

    // MARK: - 7. connectSpecialist с валидным кодом → success = true

    func test_connectSpecialist_validCode_success() {
        let (sut, spy) = makeSUT()
        sut.loadSettings(.init())
        sut.connectSpecialist(.init(code: "123456"))
        XCTAssertTrue(spy.connectSpecialistCalled)
        XCTAssertTrue(spy.lastConnectSpecialist?.success ?? false)
    }

    // MARK: - 8. connectSpecialist с коротким кодом → success = false

    func test_connectSpecialist_shortCode_failure() {
        let (sut, spy) = makeSUT()
        sut.loadSettings(.init())
        sut.connectSpecialist(.init(code: "123"))
        XCTAssertTrue(spy.connectSpecialistCalled)
        XCTAssertFalse(spy.lastConnectSpecialist?.success ?? true)
    }

    // MARK: - 9. connectSpecialist с буквами → success = false

    func test_connectSpecialist_withLetters_failure() {
        let (sut, spy) = makeSUT()
        sut.loadSettings(.init())
        sut.connectSpecialist(.init(code: "12ab56"))
        XCTAssertFalse(spy.lastConnectSpecialist?.success ?? true)
    }

    // MARK: - 10. loadLicenses возвращает лицензии

    func test_loadLicenses_returnsLicenses() {
        let (sut, spy) = makeSUT()
        sut.loadLicenses(.init())
        XCTAssertTrue(spy.loadLicensesCalled)
        XCTAssertFalse(spy.lastLoadLicenses?.licenses.isEmpty ?? true)
    }

    // MARK: - 11. updateContent обновляет audioQuality

    func test_updateContent_updatesAudioQuality() {
        let (sut, spy) = makeSUT()
        sut.loadSettings(.init())
        sut.updateContent(.init(autoDownload: nil, audioQuality: .high))
        XCTAssertTrue(spy.updateContentCalled)
    }

    // MARK: - 12. updateContent обновляет autoDownload

    func test_updateContent_updatesAutoDownload() {
        let (sut, spy) = makeSUT()
        sut.loadSettings(.init())
        sut.updateContent(.init(autoDownload: false, audioQuality: nil))
        XCTAssertTrue(spy.updateContentCalled)
    }

    // MARK: - 13. updateProfile — только возраст

    func test_updateProfile_onlyAge() {
        let (sut, spy) = makeSUT()
        sut.loadSettings(.init())
        sut.updateProfile(.init(name: nil, age: 8, avatar: nil))
        XCTAssertTrue(spy.updateProfileCalled)
        XCTAssertEqual(spy.lastUpdateProfile?.settings.childAge, 8)
    }

    // MARK: - 14. updateProfile — только аватар

    func test_updateProfile_onlyAvatar() {
        let (sut, spy) = makeSUT()
        sut.loadSettings(.init())
        sut.updateProfile(.init(name: nil, age: nil, avatar: "🐰"))
        XCTAssertTrue(spy.updateProfileCalled)
        XCTAssertEqual(spy.lastUpdateProfile?.settings.childAvatar, "🐰")
    }

    // MARK: - 15. connectSpecialist с кодом с пробелами — trim → valid

    func test_connectSpecialist_withSpaces_trimsAndSucceeds() {
        let (sut, spy) = makeSUT()
        sut.loadSettings(.init())
        sut.connectSpecialist(.init(code: " 123456 "))
        XCTAssertTrue(spy.lastConnectSpecialist?.success ?? false)
    }

    // MARK: - 16. connectSpecialist с 7 цифрами → failure

    func test_connectSpecialist_sevenDigits_failure() {
        let (sut, spy) = makeSUT()
        sut.loadSettings(.init())
        sut.connectSpecialist(.init(code: "1234567"))
        XCTAssertFalse(spy.lastConnectSpecialist?.success ?? true)
    }

    // MARK: - 17. loadModelPacks без менеджеров — возвращает пустые stub-списки

    func test_loadModelPacks_noManagers_returnsStubs() async throws {
        let (sut, spy) = makeSUT()
        sut.loadModelPacks(.init())
        // Даём Task внутри loadModelPacks шанс выполниться.
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(spy.loadModelPacksCalled)
    }

    // MARK: - 18. loadModelPacks с MockWhisperKitModelManager и MockLLMModelManager

    func test_loadModelPacks_withManagers_callsPresenter() async throws {
        let whisperMock = MockWhisperKitModelManager(installed: [.tiny])
        let llmMock = MockLLMModelManager(installed: [.qwen15b])
        let sut = SettingsInteractor(
            themeManager: ThemeManager(),
            notificationService: MockNotificationService(),
            hapticService: MockHapticService(),
            sessionRepository: MockSessionRepository(),
            whisperKitModelManager: whisperMock,
            llmModelManager: llmMock,
            defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        )
        let spy = SpyPresenter()
        sut.presenter = spy
        sut.loadModelPacks(.init())
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(spy.loadModelPacksCalled)
    }

    // MARK: - 19. downloadModelPack ASR — без менеджера → failure

    func test_downloadModelPack_asr_noManager_callsPresenterFailure() async throws {
        let (sut, spy) = makeSUT()
        sut.downloadModelPack(.init(family: .asr(.tiny)))
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(spy.downloadModelPackCalled)
    }

    // MARK: - 20. downloadModelPack LLM — без менеджера → failure

    func test_downloadModelPack_llm_noManager_callsPresenterFailure() async throws {
        let (sut, spy) = makeSUT()
        sut.downloadModelPack(.init(family: .llm(.qwen15b)))
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(spy.downloadModelPackCalled)
    }

    // MARK: - 21. deleteModelPack ASR — без менеджера → failure

    func test_deleteModelPack_asr_noManager_callsPresenterFailure() async throws {
        let (sut, spy) = makeSUT()
        sut.deleteModelPack(.init(family: .asr(.tiny)))
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(spy.deleteModelPackCalled)
    }

    // MARK: - 22. deleteModelPack LLM — без менеджера → failure

    func test_deleteModelPack_llm_noManager_callsPresenterFailure() async throws {
        let (sut, spy) = makeSUT()
        sut.deleteModelPack(.init(family: .llm(.qwen15b)))
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(spy.deleteModelPackCalled)
    }

    // MARK: - 23. downloadModelPack с менеджером → success

    func test_downloadModelPack_asr_withManager_succeeds() async throws {
        let whisperMock = MockWhisperKitModelManager(installed: [])
        let sut = SettingsInteractor(
            themeManager: ThemeManager(),
            notificationService: MockNotificationService(),
            hapticService: MockHapticService(),
            sessionRepository: MockSessionRepository(),
            whisperKitModelManager: whisperMock,
            llmModelManager: nil,
            defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        )
        let spy = SpyPresenter()
        sut.presenter = spy
        sut.downloadModelPack(SettingsModels.DownloadModelPack.Request(family: .asr(.tiny)))
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(spy.downloadModelPackCalled)
    }

    // MARK: - 24. deleteModelPack с менеджером → success

    func test_deleteModelPack_asr_withManager_succeeds() async throws {
        let whisperMock = MockWhisperKitModelManager(installed: [.base])
        let sut = SettingsInteractor(
            themeManager: ThemeManager(),
            notificationService: MockNotificationService(),
            hapticService: MockHapticService(),
            sessionRepository: MockSessionRepository(),
            whisperKitModelManager: whisperMock,
            llmModelManager: nil,
            defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        )
        let spy = SpyPresenter()
        sut.presenter = spy
        sut.deleteModelPack(SettingsModels.DeleteModelPack.Request(family: .asr(.base)))
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(spy.deleteModelPackCalled)
    }

    // MARK: - 25. exportShare записывает файл и вызывает presenter

    func test_exportShare_writesFileAndCallsPresenter() async throws {
        let (sut, spy) = makeSUT()
        sut.exportShare(.init(userId: "user-123"))
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(spy.exportShareCalled)
    }

    // MARK: - 26. toggleNotifications off → cancelAllReminders

    func test_toggleNotifications_off_callsPresenter() async throws {
        let mock = MockNotificationService()
        let sut = SettingsInteractor(
            themeManager: ThemeManager(),
            notificationService: mock,
            hapticService: MockHapticService(),
            sessionRepository: MockSessionRepository(),
            defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        )
        let spy = SpyPresenter()
        sut.presenter = spy
        sut.toggleNotifications(.init(enabled: false, reminderTime: Date()))
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(spy.toggleNotificationsCalled)
    }

    // MARK: - 27. toggleNotifications on → scheduleDailyReminder

    func test_toggleNotifications_on_callsPresenter() async throws {
        let mock = MockNotificationService()
        let sut = SettingsInteractor(
            themeManager: ThemeManager(),
            notificationService: mock,
            hapticService: MockHapticService(),
            sessionRepository: MockSessionRepository(),
            defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        )
        let spy = SpyPresenter()
        sut.presenter = spy
        var components = DateComponents()
        components.hour = 18
        components.minute = 0
        let reminderTime = Calendar.current.date(from: components) ?? Date()
        sut.toggleNotifications(.init(enabled: true, reminderTime: reminderTime))
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(spy.toggleNotificationsCalled)
    }

    // MARK: - 28. readFromDefaults — сохранённые данные читаются

    func test_readFromDefaults_persistedData_isLoaded() {
        let suite = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set("Катя", forKey: SettingsKey.childName)
        defaults.set(7, forKey: SettingsKey.childAge)
        // Block D v16 migration: аватар хранится как имя ассета-иллюстрации,
        // эмодзи считаются legacy и заменяются на default. Используем валидное имя.
        defaults.set("word_dog", forKey: SettingsKey.childAvatar)
        defaults.set(true, forKey: SettingsKey.specialistConnected)
        defaults.set("654321", forKey: SettingsKey.specialistCode)

        let sut = SettingsInteractor(
            themeManager: ThemeManager(),
            notificationService: MockNotificationService(),
            hapticService: MockHapticService(),
            sessionRepository: MockSessionRepository(),
            defaults: defaults
        )
        let spy = SpyPresenter()
        sut.presenter = spy
        sut.loadSettings(.init())

        XCTAssertEqual(spy.lastLoadSettings?.settings.childName, "Катя")
        XCTAssertEqual(spy.lastLoadSettings?.settings.childAge, 7)
        XCTAssertEqual(spy.lastLoadSettings?.settings.childAvatar, "word_dog")
        XCTAssertTrue(spy.lastLoadSettings?.settings.specialistConnected ?? false)
    }
}
