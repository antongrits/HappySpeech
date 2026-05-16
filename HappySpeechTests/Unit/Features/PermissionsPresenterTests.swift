import XCTest
@testable import HappySpeech

// MARK: - PermissionsPresenterTests
//
// Phase 2.6 batch 3 — покрытие PermissionsPresenter (25% → цель ≥90%).
// Тестируются все presentXxx методы через DisplaySpy.

@MainActor
final class PermissionsPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: PermissionsDisplayLogic {
        var startVM: PermissionsModels.Start.ViewModel?
        var requestVM: PermissionsModels.RequestPermission.ViewModel?
        var skipVM: PermissionsModels.Skip.ViewModel?
        var openSettingsVM: PermissionsModels.OpenSettings.ViewModel?
        var checkAllVM: PermissionsModels.CheckAllPermissions.ViewModel?
        var lyalyaVM: PermissionsModels.LyalyaPrompt.ViewModel?
        var deniedVM: PermissionsModels.DeniedGuidance.ViewModel?
        var failureVM: PermissionsModels.Failure.ViewModel?
        var loadingValue: Bool?

        func displayStart(_ viewModel: PermissionsModels.Start.ViewModel) { startVM = viewModel }
        func displayRequestPermission(_ viewModel: PermissionsModels.RequestPermission.ViewModel) { requestVM = viewModel }
        func displaySkip(_ viewModel: PermissionsModels.Skip.ViewModel) { skipVM = viewModel }
        func displayOpenSettings(_ viewModel: PermissionsModels.OpenSettings.ViewModel) { openSettingsVM = viewModel }
        func displayCheckAllPermissions(_ viewModel: PermissionsModels.CheckAllPermissions.ViewModel) { checkAllVM = viewModel }
        func displayLyalyaPrompt(_ viewModel: PermissionsModels.LyalyaPrompt.ViewModel) { lyalyaVM = viewModel }
        func displayDeniedGuidance(_ viewModel: PermissionsModels.DeniedGuidance.ViewModel) { deniedVM = viewModel }
        func displayFailure(_ viewModel: PermissionsModels.Failure.ViewModel) { failureVM = viewModel }
        func displayLoading(_ isLoading: Bool) { loadingValue = isLoading }
    }

    private func makeSUT() -> (PermissionsPresenter, DisplaySpy) {
        let sut = PermissionsPresenter()
        let spy = DisplaySpy()
        sut.display = spy
        return (sut, spy)
    }

    private func makeStep(_ type: PermissionType, state: PermissionState) -> PermissionStep {
        PermissionStep(
            id: type,
            icon: "mic.fill",
            title: "Микрофон",
            description: "Нужен для записи",
            allowTitle: "Разрешить",
            privacyNote: nil,
            accentColor: .primary,
            state: state
        )
    }

    // MARK: - presentStart

    func test_presentStart_singleMode_progressLabelNotEmpty() {
        let (sut, spy) = makeSUT()
        let step = makeStep(.microphone, state: .notDetermined)
        sut.presentStart(.init(steps: [step], currentIndex: 0, isSingleMode: true))
        XCTAssertNotNil(spy.startVM)
        XCTAssertTrue(spy.startVM?.isSingleMode == true)
        XCTAssertFalse(spy.startVM?.progressLabel.isEmpty ?? true)
        XCTAssertEqual(spy.startVM?.steps.count, 1)
    }

    func test_presentStart_multipleSteps_correctCurrentIndex() {
        let (sut, spy) = makeSUT()
        let steps = [
            makeStep(.microphone, state: .notDetermined),
            makeStep(.camera, state: .notDetermined)
        ]
        sut.presentStart(.init(steps: steps, currentIndex: 1, isSingleMode: false))
        XCTAssertEqual(spy.startVM?.currentIndex, 1)
        XCTAssertEqual(spy.startVM?.steps.count, 2)
    }

    func test_presentStart_zeroSteps_emptyProgressLabel() {
        let (sut, spy) = makeSUT()
        sut.presentStart(.init(steps: [], currentIndex: 0, isSingleMode: false))
        XCTAssertEqual(spy.startVM?.progressLabel, "")
    }

    // MARK: - presentRequestPermission

    func test_presentRequestPermission_granted_hasToast() {
        let (sut, spy) = makeSUT()
        let step = makeStep(.microphone, state: .granted)
        sut.presentRequestPermission(.init(
            type: .microphone,
            resultState: .granted,
            updatedSteps: [step],
            nextIndex: nil,
            isFinished: false
        ))
        XCTAssertNotNil(spy.requestVM?.toastMessage)
        XCTAssertFalse(spy.requestVM?.toastMessage?.isEmpty ?? true)
    }

    func test_presentRequestPermission_denied_hasToast() {
        let (sut, spy) = makeSUT()
        let step = makeStep(.microphone, state: .denied)
        sut.presentRequestPermission(.init(
            type: .microphone,
            resultState: .denied,
            updatedSteps: [step],
            nextIndex: nil,
            isFinished: false
        ))
        XCTAssertNotNil(spy.requestVM?.toastMessage)
    }

    func test_presentRequestPermission_restricted_hasToast() {
        let (sut, spy) = makeSUT()
        let step = makeStep(.microphone, state: .restricted)
        sut.presentRequestPermission(.init(
            type: .microphone,
            resultState: .restricted,
            updatedSteps: [step],
            nextIndex: nil,
            isFinished: false
        ))
        XCTAssertNotNil(spy.requestVM?.toastMessage)
    }

    func test_presentRequestPermission_notDetermined_nilToast() {
        let (sut, spy) = makeSUT()
        let step = makeStep(.microphone, state: .notDetermined)
        sut.presentRequestPermission(.init(
            type: .microphone,
            resultState: .notDetermined,
            updatedSteps: [step],
            nextIndex: nil,
            isFinished: false
        ))
        XCTAssertNil(spy.requestVM?.toastMessage)
    }

    func test_presentRequestPermission_skipped_nilToast() {
        let (sut, spy) = makeSUT()
        let step = makeStep(.microphone, state: .skipped)
        sut.presentRequestPermission(.init(
            type: .microphone,
            resultState: .skipped,
            updatedSteps: [step],
            nextIndex: nil,
            isFinished: false
        ))
        XCTAssertNil(spy.requestVM?.toastMessage)
    }

    func test_presentRequestPermission_finished_hasAllDoneCard() {
        let (sut, spy) = makeSUT()
        let step = makeStep(.microphone, state: .granted)
        sut.presentRequestPermission(.init(
            type: .microphone,
            resultState: .granted,
            updatedSteps: [step],
            nextIndex: nil,
            isFinished: true
        ))
        XCTAssertTrue(spy.requestVM?.isFinished == true)
        XCTAssertNotNil(spy.requestVM?.allDoneCard)
        XCTAssertEqual(spy.requestVM?.allDoneCard?.lyalyaState, .celebrating)
    }

    func test_presentRequestPermission_notFinished_nilAllDoneCard() {
        let (sut, spy) = makeSUT()
        let step = makeStep(.microphone, state: .notDetermined)
        sut.presentRequestPermission(.init(
            type: .microphone,
            resultState: .notDetermined,
            updatedSteps: [step],
            nextIndex: 0,
            isFinished: false
        ))
        XCTAssertNil(spy.requestVM?.allDoneCard)
    }

    // MARK: - presentSkip

    func test_presentSkip_notFinished_nilAllDoneCard() {
        let (sut, spy) = makeSUT()
        let step = makeStep(.microphone, state: .skipped)
        sut.presentSkip(.init(updatedSteps: [step], nextIndex: 0, isFinished: false))
        XCTAssertNil(spy.skipVM?.allDoneCard)
        XCTAssertFalse(spy.skipVM?.isFinished ?? true)
    }

    func test_presentSkip_finished_hasAllDoneCard() {
        let (sut, spy) = makeSUT()
        let step = makeStep(.microphone, state: .skipped)
        sut.presentSkip(.init(updatedSteps: [step], nextIndex: nil, isFinished: true))
        XCTAssertNotNil(spy.skipVM?.allDoneCard)
        XCTAssertTrue(spy.skipVM?.isFinished == true)
    }

    // MARK: - presentOpenSettings

    func test_presentOpenSettings_withURL_nilToast() {
        let (sut, spy) = makeSUT()
        let url = URL(string: "app-settings:")!
        sut.presentOpenSettings(.init(url: url))
        XCTAssertNotNil(spy.openSettingsVM?.url)
        XCTAssertNil(spy.openSettingsVM?.toastMessage)
    }

    func test_presentOpenSettings_nilURL_hasToast() {
        let (sut, spy) = makeSUT()
        sut.presentOpenSettings(.init(url: nil))
        XCTAssertNil(spy.openSettingsVM?.url)
        XCTAssertNotNil(spy.openSettingsVM?.toastMessage)
        XCTAssertFalse(spy.openSettingsVM?.toastMessage?.isEmpty ?? true)
    }

    // MARK: - presentCheckAllPermissions

    func test_presentCheckAllPermissions_allGranted_summaryLabel() {
        let (sut, spy) = makeSUT()
        let statuses: [PermissionType: PermissionState] = [
            .microphone: .granted,
            .camera: .granted,
            .notifications: .granted,
            .faceTracking: .granted
        ]
        sut.presentCheckAllPermissions(.init(statuses: statuses))
        XCTAssertNotNil(spy.checkAllVM)
        XCTAssertTrue(spy.checkAllVM?.allGranted == true)
        XCTAssertFalse(spy.checkAllVM?.summaryLabel.isEmpty ?? true)
    }

    func test_presentCheckAllPermissions_partial_allGrantedFalse() {
        let (sut, spy) = makeSUT()
        let statuses: [PermissionType: PermissionState] = [
            .microphone: .granted,
            .camera: .denied,
            .notifications: .notDetermined,
            .faceTracking: .notDetermined
        ]
        sut.presentCheckAllPermissions(.init(statuses: statuses))
        XCTAssertFalse(spy.checkAllVM?.allGranted ?? true)
        XCTAssertEqual(spy.checkAllVM?.grantedCount, 1)
    }

    func test_presentCheckAllPermissions_cardsCountMatchesRegistry() {
        let (sut, spy) = makeSUT()
        sut.presentCheckAllPermissions(.init(statuses: [:]))
        XCTAssertEqual(spy.checkAllVM?.cards.count, PermissionTypeRegistry.settingsOrder.count)
    }

    // MARK: - presentLyalyaPrompt

    func test_presentLyalyaPrompt_microphone_lyalyaExplaining() {
        let (sut, spy) = makeSUT()
        sut.presentLyalyaPrompt(.init(type: .microphone, prompt: "Разреши микрофон"))
        XCTAssertEqual(spy.lyalyaVM?.lyalyaState, .explaining)
        XCTAssertEqual(spy.lyalyaVM?.type, .microphone)
    }

    func test_presentLyalyaPrompt_notifications_lyalyaIdle() {
        let (sut, spy) = makeSUT()
        sut.presentLyalyaPrompt(.init(type: .notifications, prompt: "Уведомления"))
        XCTAssertEqual(spy.lyalyaVM?.lyalyaState, .idle)
    }

    func test_presentLyalyaPrompt_camera_lyalyaExplaining() {
        let (sut, spy) = makeSUT()
        sut.presentLyalyaPrompt(.init(type: .camera, prompt: "Камера"))
        XCTAssertEqual(spy.lyalyaVM?.lyalyaState, .explaining)
    }

    // MARK: - presentDeniedGuidance

    func test_presentDeniedGuidance_microphone_micSlashIcon() {
        let (sut, spy) = makeSUT()
        sut.presentDeniedGuidance(.init(type: .microphone, guidanceMessage: "Перейдите в настройки"))
        XCTAssertEqual(spy.deniedVM?.guideIcon, "mic.slash.fill")
        XCTAssertFalse(spy.deniedVM?.guidanceMessage.isEmpty ?? true)
    }

    func test_presentDeniedGuidance_camera_cameraIcon() {
        let (sut, spy) = makeSUT()
        sut.presentDeniedGuidance(.init(type: .camera, guidanceMessage: "Откройте настройки"))
        XCTAssertEqual(spy.deniedVM?.guideIcon, "camera.fill")
    }

    func test_presentDeniedGuidance_notifications_bellSlashIcon() {
        let (sut, spy) = makeSUT()
        sut.presentDeniedGuidance(.init(type: .notifications, guidanceMessage: "Включите в настройках"))
        XCTAssertEqual(spy.deniedVM?.guideIcon, "bell.slash.fill")
    }

    func test_presentDeniedGuidance_faceTracking_cameraIcon() {
        let (sut, spy) = makeSUT()
        sut.presentDeniedGuidance(.init(type: .faceTracking, guidanceMessage: "Нужна камера"))
        XCTAssertEqual(spy.deniedVM?.guideIcon, "camera.fill")
    }

    // MARK: - presentFailure

    func test_presentFailure_passesMessage() {
        let (sut, spy) = makeSUT()
        sut.presentFailure(.init(message: "Ошибка запроса"))
        XCTAssertEqual(spy.failureVM?.toastMessage, "Ошибка запроса")
    }

    // MARK: - presentLoading

    func test_presentLoading_true() {
        let (sut, spy) = makeSUT()
        sut.presentLoading(true)
        XCTAssertEqual(spy.loadingValue, true)
    }

    func test_presentLoading_false() {
        let (sut, spy) = makeSUT()
        sut.presentLoading(false)
        XCTAssertEqual(spy.loadingValue, false)
    }

    // MARK: - makeCard helpers (via presentStart)

    func test_makeCard_grantedState_isCompleted() {
        let (sut, spy) = makeSUT()
        let step = makeStep(.microphone, state: .granted)
        sut.presentStart(.init(steps: [step], currentIndex: 0, isSingleMode: false))
        let card = spy.startVM?.steps.first
        XCTAssertTrue(card?.isCompleted == true)
        XCTAssertEqual(card?.lyalyaState, .celebrating)
    }

    func test_makeCard_deniedState_showsSettingsButton() {
        let (sut, spy) = makeSUT()
        let step = makeStep(.microphone, state: .denied)
        sut.presentStart(.init(steps: [step], currentIndex: 0, isSingleMode: false))
        let card = spy.startVM?.steps.first
        XCTAssertTrue(card?.showSettingsButton == true)
        XCTAssertEqual(card?.lyalyaState, .encouraging)
    }

    func test_makeCard_restrictedState_encouraging() {
        let (sut, spy) = makeSUT()
        let step = makeStep(.microphone, state: .restricted)
        sut.presentStart(.init(steps: [step], currentIndex: 0, isSingleMode: false))
        let card = spy.startVM?.steps.first
        XCTAssertEqual(card?.lyalyaState, .encouraging)
        XCTAssertTrue(card?.showSettingsButton == true)
    }

    func test_makeCard_notDeterminedState_explaining() {
        let (sut, spy) = makeSUT()
        let step = makeStep(.microphone, state: .notDetermined)
        sut.presentStart(.init(steps: [step], currentIndex: 0, isSingleMode: false))
        let card = spy.startVM?.steps.first
        XCTAssertEqual(card?.lyalyaState, .explaining)
        XCTAssertFalse(card?.showSettingsButton ?? true)
    }

    func test_makeCard_skippedState_idle() {
        let (sut, spy) = makeSUT()
        let step = makeStep(.microphone, state: .skipped)
        sut.presentStart(.init(steps: [step], currentIndex: 0, isSingleMode: false))
        let card = spy.startVM?.steps.first
        XCTAssertEqual(card?.lyalyaState, .idle)
    }
}
