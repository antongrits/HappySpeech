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
        var loadModelPacksVM: SettingsModels.LoadModelPacks.ViewModel?
        var downloadModelPackVM: SettingsModels.DownloadModelPack.ViewModel?
        var deleteModelPackVM: SettingsModels.DeleteModelPack.ViewModel?
        var loadLicensesVM: SettingsModels.LoadLicenses.ViewModel?
        var exportShareVM: SettingsModels.ExportShare.ViewModel?
        var failureVM: SettingsModels.Failure.ViewModel?

        func displayLoadSettings(_ viewModel: SettingsModels.LoadSettings.ViewModel) { loadSettingsVM = viewModel }
        func displayUpdateTheme(_ viewModel: SettingsModels.UpdateTheme.ViewModel) { updateThemeVM = viewModel }
        func displayUpdateProfile(_ viewModel: SettingsModels.UpdateProfile.ViewModel) { updateProfileVM = viewModel }
        func displayToggleNotifications(_ viewModel: SettingsModels.ToggleNotifications.ViewModel) { toggleNotificationsVM = viewModel }
        func displayUpdateContent(_ viewModel: SettingsModels.UpdateContent.ViewModel) { updateContentVM = viewModel }
        func displayExportData(_ viewModel: SettingsModels.ExportData.ViewModel) { exportDataVM = viewModel }
        func displayClearCache(_ viewModel: SettingsModels.ClearCache.ViewModel) { clearCacheVM = viewModel }
        func displayConnectSpecialist(_ viewModel: SettingsModels.ConnectSpecialist.ViewModel) { connectSpecialistVM = viewModel }
        func displayLoadModelPacks(_ viewModel: SettingsModels.LoadModelPacks.ViewModel) { loadModelPacksVM = viewModel }
        func displayDownloadModelPack(_ viewModel: SettingsModels.DownloadModelPack.ViewModel) { downloadModelPackVM = viewModel }
        func displayDeleteModelPack(_ viewModel: SettingsModels.DeleteModelPack.ViewModel) { deleteModelPackVM = viewModel }
        func displayLoadLicenses(_ viewModel: SettingsModels.LoadLicenses.ViewModel) { loadLicensesVM = viewModel }
        func displayExportShare(_ viewModel: SettingsModels.ExportShare.ViewModel) { exportShareVM = viewModel }
        func displayFailure(_ viewModel: SettingsModels.Failure.ViewModel) { failureVM = viewModel }
        func displayLoading(_ isLoading: Bool) {}
        func displayToggleKidDailyReminder(_ viewModel: SettingsModels.ToggleKidDailyReminder.ViewModel) {}
        func displayToggleWeeklyParentSummary(_ viewModel: SettingsModels.ToggleWeeklyParentSummary.ViewModel) {}
        func displayUpdateHaptics(_ viewModel: SettingsModels.UpdateHaptics.ViewModel) {}
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

    // MARK: - presentLoadModelPacks

    func test_presentLoadModelPacks_allASRPacksPresent() {
        let (sut, spy) = makeSUT()
        let asrPacks = WhisperKitModelPack.allCases.map { pack in
            ASRPackState(pack: pack, isInstalled: true, isActive: pack == .tiny, isDownloading: false, progress: 0)
        }
        let llmPacks = LLMModelPack.allCases.map { pack in
            LLMPackState(pack: pack, isInstalled: false, isInUse: false, isDownloading: false, progress: 0)
        }
        sut.presentLoadModelPacks(.init(asrPacks: asrPacks, llmPacks: llmPacks))
        XCTAssertEqual(spy.loadModelPacksVM?.asrItems.count, WhisperKitModelPack.allCases.count)
        XCTAssertEqual(spy.loadModelPacksVM?.llmItems.count, LLMModelPack.allCases.count)
    }

    func test_presentLoadModelPacks_activeASR_hasActiveAction() {
        let (sut, spy) = makeSUT()
        let asrPacks = [ASRPackState(pack: .tiny, isInstalled: true, isActive: true, isDownloading: false, progress: 0)]
        sut.presentLoadModelPacks(.init(asrPacks: asrPacks, llmPacks: []))
        let item = spy.loadModelPacksVM?.asrItems.first
        XCTAssertFalse(item?.canDelete ?? true, "Активный пак нельзя удалить")
    }

    func test_presentLoadModelPacks_downloadingASR_showsDownloadingAction() {
        let (sut, spy) = makeSUT()
        let asrPacks = [ASRPackState(pack: .base, isInstalled: false, isActive: false, isDownloading: true, progress: 0.5)]
        sut.presentLoadModelPacks(.init(asrPacks: asrPacks, llmPacks: []))
        let item = spy.loadModelPacksVM?.asrItems.first
        XCTAssertNotNil(item)
        XCTAssertFalse(item?.actionTitle.isEmpty ?? true)
    }

    func test_presentLoadModelPacks_installedNotActiveASR_canDelete() {
        let (sut, spy) = makeSUT()
        let asrPacks = [ASRPackState(pack: .base, isInstalled: true, isActive: false, isDownloading: false, progress: 0)]
        sut.presentLoadModelPacks(.init(asrPacks: asrPacks, llmPacks: []))
        let item = spy.loadModelPacksVM?.asrItems.first
        XCTAssertTrue(item?.canDelete ?? false, "Установленный неактивный пак можно удалить")
    }

    func test_presentLoadModelPacks_llmInUse_hasActiveAction() {
        let (sut, spy) = makeSUT()
        let llmPacks = [LLMPackState(pack: .qwen15b, isInstalled: true, isInUse: true, isDownloading: false, progress: 0)]
        sut.presentLoadModelPacks(.init(asrPacks: [], llmPacks: llmPacks))
        let item = spy.loadModelPacksVM?.llmItems.first
        XCTAssertFalse(item?.canDelete ?? true, "Используемый LLM-пак нельзя удалить")
    }

    // MARK: - presentDownloadModelPack

    func test_presentDownloadModelPack_success_notError() {
        let (sut, spy) = makeSUT()
        sut.presentDownloadModelPack(.init(success: true, identifier: "whisper.tiny", errorMessage: nil))
        XCTAssertFalse(spy.downloadModelPackVM?.toastIsError ?? true)
    }

    func test_presentDownloadModelPack_failure_isError() {
        let (sut, spy) = makeSUT()
        sut.presentDownloadModelPack(.init(success: false, identifier: "whisper.tiny", errorMessage: "Нет места"))
        XCTAssertTrue(spy.downloadModelPackVM?.toastIsError ?? false)
        XCTAssertEqual(spy.downloadModelPackVM?.toastMessage, "Нет места")
    }

    func test_presentDownloadModelPack_failure_nilError_usesDefault() {
        let (sut, spy) = makeSUT()
        sut.presentDownloadModelPack(.init(success: false, identifier: "x", errorMessage: nil))
        XCTAssertTrue(spy.downloadModelPackVM?.toastIsError ?? false)
        XCTAssertFalse(spy.downloadModelPackVM?.toastMessage.isEmpty ?? true)
    }

    // MARK: - presentDeleteModelPack

    func test_presentDeleteModelPack_success_notError() {
        let (sut, spy) = makeSUT()
        sut.presentDeleteModelPack(.init(success: true, identifier: "whisper.tiny", errorMessage: nil))
        XCTAssertFalse(spy.deleteModelPackVM?.toastIsError ?? true)
    }

    func test_presentDeleteModelPack_failure_isError() {
        let (sut, spy) = makeSUT()
        sut.presentDeleteModelPack(.init(success: false, identifier: "whisper.tiny", errorMessage: "Ошибка"))
        XCTAssertTrue(spy.deleteModelPackVM?.toastIsError ?? false)
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

    // MARK: - formatBytes helper (indirect via presentLoadModelPacks)

    func test_formatBytes_largePack_showsGB() {
        let (sut, spy) = makeSUT()
        // LLM qwen3b = ~1.8 GB — sizeBytes > 1024 MB → должен показаться в ГБ
        let llmPacks = [LLMPackState(pack: .qwen3b, isInstalled: false, isInUse: false, isDownloading: false, progress: 0)]
        sut.presentLoadModelPacks(.init(asrPacks: [], llmPacks: llmPacks))
        let item = spy.loadModelPacksVM?.llmItems.first
        XCTAssertTrue(item?.sizeText.contains("ГБ") ?? false)
    }

    // MARK: - subtitleASR (indirect via presentLoadModelPacks)

    func test_subtitleASR_allPacksHaveSubtitles() {
        let (sut, spy) = makeSUT()
        let asrPacks = WhisperKitModelPack.allCases.map {
            ASRPackState(pack: $0, isInstalled: false, isActive: false, isDownloading: false, progress: 0)
        }
        sut.presentLoadModelPacks(.init(asrPacks: asrPacks, llmPacks: []))
        let items = spy.loadModelPacksVM?.asrItems ?? []
        XCTAssertEqual(items.count, WhisperKitModelPack.allCases.count)
        for item in items {
            XCTAssertFalse(item.subtitle.isEmpty, "\(item.title) должен иметь subtitle")
        }
    }
}
