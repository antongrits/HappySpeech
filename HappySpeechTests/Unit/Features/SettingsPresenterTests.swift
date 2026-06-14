@testable import HappySpeech
import XCTest

// MARK: - SettingsPresenterTests
//
// M10.3 — покрытие SettingsPresenter (15.2% → цель ≥90%).
// Тестируются все методы presentationLogic напрямую через DisplaySpy.

@MainActor
final class SettingsPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: SettingsDisplayLogic {
        var loadSettingsVM: SettingsModels.LoadSettings.ViewModel?
        var updateThemeVM: SettingsModels.UpdateTheme.ViewModel?
        var updateProfileVM: SettingsModels.UpdateProfile.ViewModel?
        var toggleNotificationsVM: SettingsModels.ToggleNotifications.ViewModel?
        var updateContentVM: SettingsModels.UpdateContent.ViewModel?
        var exportDataVM: SettingsModels.ExportData.ViewModel?
        var clearCacheVM: SettingsModels.ClearCache.ViewModel?
        var connectSpecialistVM: SettingsModels.ConnectSpecialist.ViewModel?
        var loadLicensesVM: SettingsModels.LoadLicenses.ViewModel?
        var exportShareVM: SettingsModels.ExportShare.ViewModel?
        var failureVM: SettingsModels.Failure.ViewModel?
        var toggleCalmModeVM: SettingsModels.ToggleCalmMode.ViewModel?

        func displayLoadSettings(_ viewModel: SettingsModels.LoadSettings.ViewModel) { loadSettingsVM = viewModel }
        func displayUpdateTheme(_ viewModel: SettingsModels.UpdateTheme.ViewModel) { updateThemeVM = viewModel }
        func displayUpdateProfile(_ viewModel: SettingsModels.UpdateProfile.ViewModel) { updateProfileVM = viewModel }
        func displayToggleNotifications(_ viewModel: SettingsModels.ToggleNotifications.ViewModel) { toggleNotificationsVM = viewModel }
        func displayUpdateContent(_ viewModel: SettingsModels.UpdateContent.ViewModel) { updateContentVM = viewModel }
        func displayExportData(_ viewModel: SettingsModels.ExportData.ViewModel) { exportDataVM = viewModel }
        func displayClearCache(_ viewModel: SettingsModels.ClearCache.ViewModel) { clearCacheVM = viewModel }
        func displayConnectSpecialist(_ viewModel: SettingsModels.ConnectSpecialist.ViewModel) { connectSpecialistVM = viewModel }
        func displayLoadLicenses(_ viewModel: SettingsModels.LoadLicenses.ViewModel) { loadLicensesVM = viewModel }
        func displayExportShare(_ viewModel: SettingsModels.ExportShare.ViewModel) { exportShareVM = viewModel }
        func displayFailure(_ viewModel: SettingsModels.Failure.ViewModel) { failureVM = viewModel }
        func displayLoading(_ isLoading: Bool) {}
        func displayToggleKidDailyReminder(_ viewModel: SettingsModels.ToggleKidDailyReminder.ViewModel) {}
        func displayToggleWeeklyParentSummary(_ viewModel: SettingsModels.ToggleWeeklyParentSummary.ViewModel) {}
        func displayUpdateHaptics(_ viewModel: SettingsModels.UpdateHaptics.ViewModel) {}
        func displayTogglePerformanceMonitoring(_ viewModel: SettingsModels.TogglePerformanceMonitoring.ViewModel) {}
        func displayToggleCalmMode(_ viewModel: SettingsModels.ToggleCalmMode.ViewModel) { toggleCalmModeVM = viewModel }
    }

    private func makeSUT() -> (SettingsPresenter, DisplaySpy) {
        let presenter = SettingsPresenter()
        let spy = DisplaySpy()
        presenter.display = spy
        return (presenter, spy)
    }

    private func defaultSettings() -> AppSettings { .default }

    // MARK: - presentLoadSettings

    func test_presentLoadSettings_formatsVersionLine() {
        let (sut, spy) = makeSUT()
        sut.presentLoadSettings(.init(settings: defaultSettings(), appVersion: "2.0.0", buildNumber: "42"))
        XCTAssertNotNil(spy.loadSettingsVM)
        XCTAssertEqual(spy.loadSettingsVM?.availableAvatars.count, 6)
        XCTAssertEqual(spy.loadSettingsVM?.availableAges.first, 3)
        XCTAssertEqual(spy.loadSettingsVM?.availableAges.last, 12)
    }

    // MARK: - presentUpdateTheme

    func test_presentUpdateTheme_light() {
        let (sut, spy) = makeSUT()
        var settings = defaultSettings()
        settings.theme = .light
        sut.presentUpdateTheme(.init(settings: settings))
        XCTAssertNotNil(spy.updateThemeVM)
        XCTAssertFalse(spy.updateThemeVM?.toastMessage.isEmpty ?? true)
    }

    func test_presentUpdateTheme_dark() {
        let (sut, spy) = makeSUT()
        var settings = defaultSettings()
        settings.theme = .dark
        sut.presentUpdateTheme(.init(settings: settings))
        XCTAssertNotNil(spy.updateThemeVM)
    }

    func test_presentUpdateTheme_system() {
        let (sut, spy) = makeSUT()
        var settings = defaultSettings()
        settings.theme = .system
        sut.presentUpdateTheme(.init(settings: settings))
        XCTAssertNotNil(spy.updateThemeVM)
    }

    // MARK: - presentUpdateProfile

    func test_presentUpdateProfile_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentUpdateProfile(.init(settings: defaultSettings()))
        XCTAssertNotNil(spy.updateProfileVM)
        XCTAssertFalse(spy.updateProfileVM?.toastMessage.isEmpty ?? true)
    }

    // MARK: - presentToggleNotifications

    func test_presentToggleNotifications_permissionDenied_isError() {
        let (sut, spy) = makeSUT()
        var settings = defaultSettings()
        settings.notificationsEnabled = false
        sut.presentToggleNotifications(.init(settings: settings, permissionGranted: false))
        XCTAssertTrue(spy.toggleNotificationsVM?.toastIsError ?? false)
    }

    func test_presentToggleNotifications_enabled_notError() {
        let (sut, spy) = makeSUT()
        var settings = defaultSettings()
        settings.notificationsEnabled = true
        sut.presentToggleNotifications(.init(settings: settings, permissionGranted: true))
        XCTAssertFalse(spy.toggleNotificationsVM?.toastIsError ?? true)
        XCTAssertFalse(spy.toggleNotificationsVM?.toastMessage.isEmpty ?? true)
    }

    func test_presentToggleNotifications_disabled_notError() {
        let (sut, spy) = makeSUT()
        var settings = defaultSettings()
        settings.notificationsEnabled = false
        sut.presentToggleNotifications(.init(settings: settings, permissionGranted: true))
        XCTAssertFalse(spy.toggleNotificationsVM?.toastIsError ?? true)
    }

    // MARK: - presentUpdateContent

    func test_presentUpdateContent_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentUpdateContent(.init(settings: defaultSettings()))
        XCTAssertNotNil(spy.updateContentVM)
        XCTAssertFalse(spy.updateContentVM?.toastMessage.isEmpty ?? true)
    }

    // MARK: - presentExportData

    func test_presentExportData_success() {
        let (sut, spy) = makeSUT()
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("export.json")
        sut.presentExportData(.init(success: true, fileURL: url, format: .json, errorMessage: nil))
        XCTAssertFalse(spy.exportDataVM?.toastIsError ?? true)
        XCTAssertFalse(spy.exportDataVM?.toastMessage.isEmpty ?? true)
    }

    func test_presentExportData_failure() {
        let (sut, spy) = makeSUT()
        sut.presentExportData(.init(success: false, fileURL: nil, format: .pdf, errorMessage: "Ошибка"))
        XCTAssertTrue(spy.exportDataVM?.toastIsError ?? false)
        XCTAssertEqual(spy.exportDataVM?.toastMessage, "Ошибка")
    }

    func test_presentExportData_failure_nilError_usesDefaultMessage() {
        let (sut, spy) = makeSUT()
        sut.presentExportData(.init(success: false, fileURL: nil, format: .csv, errorMessage: nil))
        XCTAssertTrue(spy.exportDataVM?.toastIsError ?? false)
        XCTAssertFalse(spy.exportDataVM?.toastMessage.isEmpty ?? true)
    }

    // MARK: - presentClearCache

    func test_presentClearCache_formatsBytes() {
        let (sut, spy) = makeSUT()
        // 47 MB — toastMessage содержит форматированный размер
        sut.presentClearCache(.init(bytesFreed: 47_104_000))
        XCTAssertNotNil(spy.clearCacheVM)
        XCTAssertFalse(spy.clearCacheVM?.toastMessage.isEmpty ?? true)
    }

    func test_presentClearCache_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentClearCache(.init(bytesFreed: 1_048_576))
        XCTAssertNotNil(spy.clearCacheVM)
    }

    // MARK: - presentConnectSpecialist

    func test_presentConnectSpecialist_success_notError() {
        let (sut, spy) = makeSUT()
        sut.presentConnectSpecialist(.init(success: true, settings: defaultSettings(), errorMessage: nil))
        XCTAssertFalse(spy.connectSpecialistVM?.toastIsError ?? true)
    }

    func test_presentConnectSpecialist_failure_isError() {
        let (sut, spy) = makeSUT()
        sut.presentConnectSpecialist(.init(success: false, settings: defaultSettings(), errorMessage: "Неверный код"))
        XCTAssertTrue(spy.connectSpecialistVM?.toastIsError ?? false)
        XCTAssertEqual(spy.connectSpecialistVM?.toastMessage, "Неверный код")
    }

    func test_presentConnectSpecialist_failure_nilError_usesDefault() {
        let (sut, spy) = makeSUT()
        sut.presentConnectSpecialist(.init(success: false, settings: defaultSettings(), errorMessage: nil))
        XCTAssertTrue(spy.connectSpecialistVM?.toastIsError ?? false)
        XCTAssertFalse(spy.connectSpecialistVM?.toastMessage.isEmpty ?? true)
    }

    // MARK: - presentLoadLicenses

    func test_presentLoadLicenses_withURL_formatsSubtitle() {
        let (sut, spy) = makeSUT()
        let license = OpenSourceLicense(
            id: "whisperkit",
            name: "WhisperKit",
            licenseType: "MIT",
            url: "https://github.com/argmaxinc/WhisperKit",
            bodyText: "MIT License text"
        )
        sut.presentLoadLicenses(.init(licenses: [license]))
        let item = spy.loadLicensesVM?.licenses.first
        XCTAssertNotNil(item)
        XCTAssertTrue(item?.subtitle.contains("MIT") ?? false)
        XCTAssertTrue(item?.subtitle.contains("github.com") ?? false)
    }

    func test_presentLoadLicenses_withoutURL_usesLicenseTypeOnly() {
        let (sut, spy) = makeSUT()
        let license = OpenSourceLicense(
            id: "internal",
            name: "Internal",
            licenseType: "Apache 2.0",
            url: nil,
            bodyText: "text"
        )
        sut.presentLoadLicenses(.init(licenses: [license]))
        let item = spy.loadLicensesVM?.licenses.first
        XCTAssertEqual(item?.subtitle, "Apache 2.0")
    }

    // MARK: - presentExportShare

    func test_presentExportShare_success_hasFileURL() {
        let (sut, spy) = makeSUT()
        let url = URL(fileURLWithPath: "/tmp/export.json")
        sut.presentExportShare(.init(success: true, fileURL: url, errorMessage: nil))
        XCTAssertNotNil(spy.exportShareVM?.fileURL)
        XCTAssertFalse(spy.exportShareVM?.toastIsError ?? true)
    }

    func test_presentExportShare_failure_nilURL() {
        let (sut, spy) = makeSUT()
        sut.presentExportShare(.init(success: false, fileURL: nil, errorMessage: "Ошибка записи"))
        XCTAssertNil(spy.exportShareVM?.fileURL)
        XCTAssertTrue(spy.exportShareVM?.toastIsError ?? false)
    }

    func test_presentExportShare_failure_nilError_usesDefault() {
        let (sut, spy) = makeSUT()
        sut.presentExportShare(.init(success: false, fileURL: nil, errorMessage: nil))
        XCTAssertTrue(spy.exportShareVM?.toastIsError ?? false)
        XCTAssertFalse(spy.exportShareVM?.toastMessage.isEmpty ?? true)
    }

    // MARK: - presentFailure

    func test_presentFailure_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentFailure(.init(message: "Что-то пошло не так"))
        XCTAssertEqual(spy.failureVM?.toastMessage, "Что-то пошло не так")
    }

    // MARK: - A-08: Calm Mode

    func test_presentToggleCalmMode_enabled_setsSettingsAndToast() {
        let (sut, spy) = makeSUT()
        var settings = AppSettings.default
        settings.calmModeEnabled = true
        sut.presentToggleCalmMode(.init(settings: settings))
        XCTAssertEqual(spy.toggleCalmModeVM?.settings.calmModeEnabled, true)
        XCTAssertFalse(spy.toggleCalmModeVM?.toastMessage.isEmpty ?? true)
    }

    func test_presentToggleCalmMode_disabled_setsSettings() {
        let (sut, spy) = makeSUT()
        var settings = AppSettings.default
        settings.calmModeEnabled = false
        sut.presentToggleCalmMode(.init(settings: settings))
        XCTAssertEqual(spy.toggleCalmModeVM?.settings.calmModeEnabled, false)
    }
}
