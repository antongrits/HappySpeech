@testable import HappySpeech
import XCTest

// MARK: - PermissionsInteractorTests
//
// M10.1 — 6 тестов для PermissionsInteractor.
// Покрывает: start (all/single mode), skipPermission (not-determined/last),
// openSettings, checkAllPermissions.
//
// Explained gap: requestPermission() вызывает системный диалог
// (AVCaptureDevice.requestAccess) — не тестируется в симуляторе без разрешений.

@MainActor
final class PermissionsInteractorTests: XCTestCase {

    // MARK: - Spy

    @MainActor
    private final class SpyPresenter: PermissionsPresentationLogic {
        var startCalled = false
        var requestPermissionCalled = false
        var skipCalled = false
        var openSettingsCalled = false
        var checkAllCalled = false
        var failureCalled = false
        var loadingCalled = false

        var lastStartResponse: PermissionsModels.Start.Response?
        var lastSkipResponse: PermissionsModels.Skip.Response?
        var lastOpenSettingsResponse: PermissionsModels.OpenSettings.Response?
        var lastCheckAllResponse: PermissionsModels.CheckAllPermissions.Response?

        func presentStart(_ response: PermissionsModels.Start.Response) {
            startCalled = true; lastStartResponse = response
        }
        func presentRequestPermission(_ response: PermissionsModels.RequestPermission.Response) {
            requestPermissionCalled = true
            lastRequestResponse = response
        }
        func presentSkip(_ response: PermissionsModels.Skip.Response) {
            skipCalled = true; lastSkipResponse = response
        }
        func presentOpenSettings(_ response: PermissionsModels.OpenSettings.Response) {
            openSettingsCalled = true; lastOpenSettingsResponse = response
        }
        func presentCheckAllPermissions(_ response: PermissionsModels.CheckAllPermissions.Response) {
            checkAllCalled = true; lastCheckAllResponse = response
        }
        func presentFailure(_ response: PermissionsModels.Failure.Response) {
            failureCalled = true
            lastFailureResponse = response
        }
        func presentLoading(_ isLoading: Bool) {
            loadingCalled = true
        }
        var lyalyaPromptCalled = false
        var deniedGuidanceCalled = false
        var lastLyalyaResponse: PermissionsModels.LyalyaPrompt.Response?
        var lastDeniedGuidance: PermissionsModels.DeniedGuidance.Response?
        var lastRequestResponse: PermissionsModels.RequestPermission.Response?
        var lastFailureResponse: PermissionsModels.Failure.Response?

        func presentLyalyaPrompt(_ response: PermissionsModels.LyalyaPrompt.Response) {
            lyalyaPromptCalled = true
            lastLyalyaResponse = response
        }
        func presentDeniedGuidance(_ response: PermissionsModels.DeniedGuidance.Response) {
            deniedGuidanceCalled = true
            lastDeniedGuidance = response
        }
    }

    private func makeSUT() -> (PermissionsInteractor, SpyPresenter) {
        let sut = PermissionsInteractor()
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. start (all permissions) строит шаги для всех типов

    func test_start_allPermissions_buildsStepList() {
        let (sut, spy) = makeSUT()
        sut.start(.init(single: nil))
        XCTAssertTrue(spy.startCalled)
        let steps = spy.lastStartResponse?.steps ?? []
        XCTAssertFalse(steps.isEmpty)
        XCTAssertEqual(spy.lastStartResponse?.isSingleMode, false)
    }

    // MARK: - 2. start (single mode) строит ровно один шаг

    func test_start_singleMode_buildsOneStep() {
        let (sut, spy) = makeSUT()
        sut.start(.init(single: .microphone))
        XCTAssertTrue(spy.startCalled)
        XCTAssertEqual(spy.lastStartResponse?.steps.count, 1)
        XCTAssertEqual(spy.lastStartResponse?.isSingleMode, true)
    }

    // MARK: - 3. skipPermission в single mode → isFinished = true

    func test_skipPermission_singleMode_isFinished() {
        let (sut, spy) = makeSUT()
        sut.start(.init(single: .microphone))
        sut.skipPermission(.init(type: .microphone))
        XCTAssertTrue(spy.skipCalled)
        XCTAssertEqual(spy.lastSkipResponse?.isFinished, true)
    }

    // MARK: - 4. skipPermission на последнем шаге full mode → isFinished = true

    func test_skipPermission_lastStepFullMode_isFinished() {
        let (sut, spy) = makeSUT()
        sut.start(.init(single: nil))
        // Последний шаг в onboardingOrder — .faceTracking.
        let lastType = PermissionTypeRegistry.onboardingOrder.last!
        sut.skipPermission(.init(type: lastType))
        XCTAssertTrue(spy.skipCalled)
        XCTAssertEqual(spy.lastSkipResponse?.isFinished, true)
    }

    // MARK: - 5. openSettings вызывает presentOpenSettings

    func test_openSettings_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.openSettings(.init())
        XCTAssertTrue(spy.openSettingsCalled)
        XCTAssertNotNil(spy.lastOpenSettingsResponse?.url)
    }

    // MARK: - 6. checkAllPermissions возвращает статусы для всех типов

    func test_checkAllPermissions_returnsStatusesForAllTypes() {
        let (sut, spy) = makeSUT()
        sut.checkAllPermissions(.init())
        XCTAssertTrue(spy.checkAllCalled)
        let statuses = spy.lastCheckAllResponse?.statuses ?? [:]
        XCTAssertFalse(statuses.isEmpty)
        // Проверяем что микрофон и камера присутствуют.
        XCTAssertNotNil(statuses[.microphone])
        XCTAssertNotNil(statuses[.camera])
        XCTAssertNotNil(statuses[.notifications])
        XCTAssertNotNil(statuses[.faceTracking])
    }

    // MARK: - 7. requestPermission с неизвестным типом → presentFailure
    //
    // Тип отсутствует в steps (steps пустой до start) → failure.

    func test_requestPermission_unknownType_callsFailure() {
        let (sut, spy) = makeSUT()
        // start не вызван — steps пустой, любой тип «неизвестен»
        sut.requestPermission(.init(type: .microphone))
        XCTAssertTrue(spy.failureCalled)
        XCTAssertFalse(spy.lastFailureResponse?.message.isEmpty ?? true)
    }

    // MARK: - 8. skipPermission неизвестного типа игнорируется

    func test_skipPermission_unknownType_ignored() {
        let (sut, spy) = makeSUT()
        sut.start(.init(single: .microphone))
        spy.skipCalled = false
        // .notifications нет в single-mode steps
        sut.skipPermission(.init(type: .notifications))
        XCTAssertFalse(spy.skipCalled)
    }

    // MARK: - 9. skipPermission не на последнем шаге → isFinished = false

    func test_skipPermission_firstStepFullMode_notFinished() {
        let (sut, spy) = makeSUT()
        sut.start(.init(single: nil))
        sut.skipPermission(.init(type: .microphone))
        XCTAssertTrue(spy.skipCalled)
        XCTAssertEqual(spy.lastSkipResponse?.isFinished, false)
        XCTAssertNotNil(spy.lastSkipResponse?.nextIndex)
    }

    // MARK: - 10. retryPermission для микрофона → редирект в Settings

    func test_retryPermission_microphone_opensSettings() {
        let (sut, spy) = makeSUT()
        sut.retryPermission(.init(type: .microphone))
        XCTAssertTrue(spy.openSettingsCalled)
    }

    func test_retryPermission_camera_opensSettings() {
        let (sut, spy) = makeSUT()
        sut.retryPermission(.init(type: .camera))
        XCTAssertTrue(spy.openSettingsCalled)
    }

    func test_retryPermission_faceTracking_opensSettings() {
        let (sut, spy) = makeSUT()
        sut.retryPermission(.init(type: .faceTracking))
        XCTAssertTrue(spy.openSettingsCalled)
    }

    // MARK: - 11. checkSinglePermission обновляет статус

    func test_checkSinglePermission_callsCheckAll() {
        let (sut, spy) = makeSUT()
        sut.checkSinglePermission(.init(type: .microphone))
        XCTAssertTrue(spy.checkAllCalled)
        XCTAssertNotNil(spy.lastCheckAllResponse?.statuses[.microphone])
    }

    func test_checkSinglePermission_withActiveFlow_updatesStep() {
        let (sut, spy) = makeSUT()
        sut.start(.init(single: .microphone))
        spy.requestPermissionCalled = false
        sut.checkSinglePermission(.init(type: .microphone))
        // Шаг присутствует во flow → presentRequestPermission также вызывается
        XCTAssertTrue(spy.requestPermissionCalled)
    }

    // MARK: - 12. refreshOnForeground перечитывает статусы

    func test_refreshOnForeground_callsCheckAll() {
        let (sut, spy) = makeSUT()
        sut.start(.init(single: nil))
        spy.checkAllCalled = false
        sut.refreshOnForeground()
        XCTAssertTrue(spy.checkAllCalled)
    }

    // MARK: - 13. getLyalyaVoicePrompt возвращает реплику для каждого состояния

    func test_getLyalyaVoicePrompt_grantedState_returnsPrompt() {
        let (sut, spy) = makeSUT()
        sut.getLyalyaVoicePrompt(.init(type: .microphone, state: .granted))
        XCTAssertTrue(spy.lyalyaPromptCalled)
        XCTAssertEqual(spy.lastLyalyaResponse?.type, .microphone)
        XCTAssertFalse(spy.lastLyalyaResponse?.prompt.isEmpty ?? true)
    }

    func test_getLyalyaVoicePrompt_deniedState_returnsPrompt() {
        let (sut, spy) = makeSUT()
        sut.getLyalyaVoicePrompt(.init(type: .camera, state: .denied))
        XCTAssertFalse(spy.lastLyalyaResponse?.prompt.isEmpty ?? true)
    }

    func test_getLyalyaVoicePrompt_notDeterminedState_returnsPrompt() {
        let (sut, spy) = makeSUT()
        sut.getLyalyaVoicePrompt(.init(type: .notifications, state: .notDetermined))
        XCTAssertFalse(spy.lastLyalyaResponse?.prompt.isEmpty ?? true)
    }

    func test_getLyalyaVoicePrompt_skippedState_returnsPrompt() {
        let (sut, spy) = makeSUT()
        sut.getLyalyaVoicePrompt(.init(type: .faceTracking, state: .skipped))
        XCTAssertFalse(spy.lastLyalyaResponse?.prompt.isEmpty ?? true)
    }

    func test_getLyalyaVoicePrompt_restrictedState_returnsPrompt() {
        let (sut, spy) = makeSUT()
        sut.getLyalyaVoicePrompt(.init(type: .camera, state: .restricted))
        XCTAssertFalse(spy.lastLyalyaResponse?.prompt.isEmpty ?? true)
    }

    // MARK: - 14. getDeniedGuidance возвращает инструкцию для каждого типа

    func test_getDeniedGuidance_microphone_returnsGuidance() {
        let (sut, spy) = makeSUT()
        sut.getDeniedGuidance(.init(type: .microphone))
        XCTAssertTrue(spy.deniedGuidanceCalled)
        XCTAssertEqual(spy.lastDeniedGuidance?.type, .microphone)
        XCTAssertFalse(spy.lastDeniedGuidance?.guidanceMessage.isEmpty ?? true)
    }

    func test_getDeniedGuidance_camera_returnsGuidance() {
        let (sut, spy) = makeSUT()
        sut.getDeniedGuidance(.init(type: .camera))
        XCTAssertFalse(spy.lastDeniedGuidance?.guidanceMessage.isEmpty ?? true)
    }

    func test_getDeniedGuidance_notifications_returnsGuidance() {
        let (sut, spy) = makeSUT()
        sut.getDeniedGuidance(.init(type: .notifications))
        XCTAssertFalse(spy.lastDeniedGuidance?.guidanceMessage.isEmpty ?? true)
    }

    func test_getDeniedGuidance_faceTracking_returnsGuidance() {
        let (sut, spy) = makeSUT()
        sut.getDeniedGuidance(.init(type: .faceTracking))
        XCTAssertFalse(spy.lastDeniedGuidance?.guidanceMessage.isEmpty ?? true)
    }

    // MARK: - 15. restoreStatusSnapshot после start возвращает снапшот

    func test_restoreStatusSnapshot_afterStart_returnsSnapshot() {
        let (sut, _) = makeSUT()
        sut.start(.init(single: nil))
        let snapshot = sut.restoreStatusSnapshot()
        XCTAssertFalse(snapshot.isEmpty)
    }

    // MARK: - 16. cancelForegroundObserver не крашит

    func test_cancelForegroundObserver_afterStart_doesNotCrash() {
        let (sut, _) = makeSUT()
        sut.start(.init(single: nil))
        sut.cancelForegroundObserver()
        XCTAssertTrue(true)
    }

    // MARK: - 17. PermissionType helpers round-trip

    func test_permissionType_systemNameRoundTrip() {
        for type in PermissionTypeRegistry.onboardingOrder {
            let name = type.systemName
            XCTAssertEqual(PermissionType.fromSystemName(name), type)
        }
        XCTAssertNil(PermissionType.fromSystemName("invalid"))
    }

    func test_permissionState_persistenceKeyRoundTrip() {
        let states: [PermissionState] = [.notDetermined, .granted, .denied, .restricted, .skipped]
        for state in states {
            let key = state.persistenceKey
            XCTAssertEqual(PermissionState.fromPersistenceKey(key), state)
        }
        XCTAssertNil(PermissionState.fromPersistenceKey("invalid"))
    }

    // MARK: - 18. retryPermission notifications с denied (системно) → Settings
    //
    // currentSystemState(.notifications) всегда .notDetermined в этой реализации,
    // поэтому notifications retry приводит к re-request (presentLoading вызывается).

    func test_retryPermission_notifications_triggersFlow() {
        let (sut, spy) = makeSUT()
        sut.start(.init(single: .notifications))
        sut.retryPermission(.init(type: .notifications))
        // notifications notDetermined → re-request → presentLoading
        XCTAssertTrue(spy.loadingCalled)
    }
}
