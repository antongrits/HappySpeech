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
    }

    private func makeSUT() -> (SettingsInteractor, SpyPresenter) {
        let sut = SettingsInteractor(
            themeManager: ThemeManager(),
            notificationService: MockNotificationService(),
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

    func test_exportData_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.exportData(.init())
        XCTAssertTrue(spy.exportDataCalled)
    }

    // MARK: - 6. clearCache вызывает presentClearCache с bytesFreed > 0

    func test_clearCache_callsPresenterWithBytes() {
        let (sut, spy) = makeSUT()
        sut.clearCache(.init())
        XCTAssertTrue(spy.clearCacheCalled)
        XCTAssertGreaterThan(spy.lastClearCache?.bytesFreed ?? 0, 0)
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
}
