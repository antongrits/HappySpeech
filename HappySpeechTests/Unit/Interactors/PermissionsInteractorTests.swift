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
        }
        func presentLoading(_ isLoading: Bool) {
            loadingCalled = true
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
    }
}
