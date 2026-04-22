import XCTest
@testable import HappySpeech

// MARK: - Spy helpers for standard VIP features

@MainActor
private final class SpyAuthPresenter: AuthPresentationLogic {
    var fetchCalled = false
    var updateCalled = false
    func presentFetch(_ response: AuthModels.Fetch.Response) { fetchCalled = true }
    func presentUpdate(_ response: AuthModels.Update.Response) { updateCalled = true }
}

@MainActor
private final class SpyOnboardingPresenter: OnboardingPresentationLogic {
    var fetchCalled = false
    var updateCalled = false
    func presentFetch(_ response: OnboardingModels.Fetch.Response) { fetchCalled = true }
    func presentUpdate(_ response: OnboardingModels.Update.Response) { updateCalled = true }
}

@MainActor
private final class SpySettingsPresenter: SettingsPresentationLogic {
    var fetchCalled = false
    var updateCalled = false
    func presentFetch(_ response: SettingsModels.Fetch.Response) { fetchCalled = true }
    func presentUpdate(_ response: SettingsModels.Update.Response) { updateCalled = true }
}

@MainActor
private final class SpyWorldMapPresenter: WorldMapPresentationLogic {
    var fetchCalled = false
    var updateCalled = false
    func presentFetch(_ response: WorldMapModels.Fetch.Response) { fetchCalled = true }
    func presentUpdate(_ response: WorldMapModels.Update.Response) { updateCalled = true }
}

@MainActor
private final class SpyProgressDashboardPresenter: ProgressDashboardPresentationLogic {
    var fetchCalled = false
    var updateCalled = false
    func presentFetch(_ response: ProgressDashboardModels.Fetch.Response) { fetchCalled = true }
    func presentUpdate(_ response: ProgressDashboardModels.Update.Response) { updateCalled = true }
}

@MainActor
private final class SpySessionCompletePresenter: SessionCompletePresentationLogic {
    var fetchCalled = false
    var updateCalled = false
    func presentFetch(_ response: SessionCompleteModels.Fetch.Response) { fetchCalled = true }
    func presentUpdate(_ response: SessionCompleteModels.Update.Response) { updateCalled = true }
}

@MainActor
private final class SpyRewardsPresenter: RewardsPresentationLogic {
    var fetchCalled = false
    var updateCalled = false
    func presentFetch(_ response: RewardsModels.Fetch.Response) { fetchCalled = true }
    func presentUpdate(_ response: RewardsModels.Update.Response) { updateCalled = true }
}

@MainActor
private final class SpyDemoPresenter: DemoPresentationLogic {
    var fetchCalled = false
    var updateCalled = false
    func presentFetch(_ response: DemoModels.Fetch.Response) { fetchCalled = true }
    func presentUpdate(_ response: DemoModels.Update.Response) { updateCalled = true }
}

@MainActor
private final class SpyHomeTasksPresenter: HomeTasksPresentationLogic {
    var fetchCalled = false
    var updateCalled = false
    func presentFetch(_ response: HomeTasksModels.Fetch.Response) { fetchCalled = true }
    func presentUpdate(_ response: HomeTasksModels.Update.Response) { updateCalled = true }
}

@MainActor
private final class SpyARZonePresenter: ARZonePresentationLogic {
    var fetchCalled = false
    var updateCalled = false
    func presentFetch(_ response: ARZoneModels.Fetch.Response) { fetchCalled = true }
    func presentUpdate(_ response: ARZoneModels.Update.Response) { updateCalled = true }
}

@MainActor
private final class SpyOfflineStatePresenter: OfflineStatePresentationLogic {
    var fetchCalled = false
    var updateCalled = false
    func presentFetch(_ response: OfflineStateModels.Fetch.Response) { fetchCalled = true }
    func presentUpdate(_ response: OfflineStateModels.Update.Response) { updateCalled = true }
}

@MainActor
private final class SpySpecialistPresenter: SpecialistPresentationLogic {
    var fetchCalled = false
    var updateCalled = false
    func presentFetch(_ response: SpecialistModels.Fetch.Response) { fetchCalled = true }
    func presentUpdate(_ response: SpecialistModels.Update.Response) { updateCalled = true }
}

@MainActor
private final class SpySessionHistoryPresenter: SessionHistoryPresentationLogic {
    var fetchCalled = false
    var updateCalled = false
    func presentFetch(_ response: SessionHistoryModels.Fetch.Response) { fetchCalled = true }
    func presentUpdate(_ response: SessionHistoryModels.Update.Response) { updateCalled = true }
}

@MainActor
private final class SpyPermissionsPresenter: PermissionsPresentationLogic {
    var fetchCalled = false
    var updateCalled = false
    func presentFetch(_ response: PermissionsModels.Fetch.Response) { fetchCalled = true }
    func presentUpdate(_ response: PermissionsModels.Update.Response) { updateCalled = true }
}

// MARK: - AuthInteractorTests

@MainActor
final class AuthInteractorTests: XCTestCase {

    func testFetch_callsPresenterPresentFetch() {
        let interactor = AuthInteractor()
        let spy = SpyAuthPresenter()
        interactor.presenter = spy
        interactor.fetch(AuthModels.Fetch.Request())
        XCTAssertTrue(spy.fetchCalled)
    }

    func testUpdate_callsPresenterPresentUpdate() {
        let interactor = AuthInteractor()
        let spy = SpyAuthPresenter()
        interactor.presenter = spy
        interactor.update(AuthModels.Update.Request())
        XCTAssertTrue(spy.updateCalled)
    }

    func testFetch_doesNotCallPresentUpdateUnintentionally() {
        let interactor = AuthInteractor()
        let spy = SpyAuthPresenter()
        interactor.presenter = spy
        interactor.fetch(AuthModels.Fetch.Request())
        XCTAssertFalse(spy.updateCalled)
    }

    func testUpdate_doesNotCallPresentFetchUnintentionally() {
        let interactor = AuthInteractor()
        let spy = SpyAuthPresenter()
        interactor.presenter = spy
        interactor.update(AuthModels.Update.Request())
        XCTAssertFalse(spy.fetchCalled)
    }

    func testNilPresenter_doesNotCrash() {
        let interactor = AuthInteractor()
        interactor.presenter = nil
        interactor.fetch(AuthModels.Fetch.Request())
        interactor.update(AuthModels.Update.Request())
    }
}

// MARK: - OnboardingInteractorTests

@MainActor
final class OnboardingInteractorTests: XCTestCase {

    func testFetch_callsPresenterPresentFetch() {
        let interactor = OnboardingInteractor()
        let spy = SpyOnboardingPresenter()
        interactor.presenter = spy
        interactor.fetch(OnboardingModels.Fetch.Request())
        XCTAssertTrue(spy.fetchCalled)
    }

    func testUpdate_callsPresenterPresentUpdate() {
        let interactor = OnboardingInteractor()
        let spy = SpyOnboardingPresenter()
        interactor.presenter = spy
        interactor.update(OnboardingModels.Update.Request())
        XCTAssertTrue(spy.updateCalled)
    }
}

// MARK: - SettingsInteractorTests

@MainActor
final class SettingsInteractorTests: XCTestCase {

    func testFetch_callsPresenterPresentFetch() {
        let interactor = SettingsInteractor()
        let spy = SpySettingsPresenter()
        interactor.presenter = spy
        interactor.fetch(SettingsModels.Fetch.Request())
        XCTAssertTrue(spy.fetchCalled)
    }

    func testUpdate_callsPresenterPresentUpdate() {
        let interactor = SettingsInteractor()
        let spy = SpySettingsPresenter()
        interactor.presenter = spy
        interactor.update(SettingsModels.Update.Request())
        XCTAssertTrue(spy.updateCalled)
    }
}

// MARK: - WorldMapInteractorTests

@MainActor
final class WorldMapInteractorTests: XCTestCase {

    func testFetch_callsPresenterPresentFetch() {
        let interactor = WorldMapInteractor()
        let spy = SpyWorldMapPresenter()
        interactor.presenter = spy
        interactor.fetch(WorldMapModels.Fetch.Request())
        XCTAssertTrue(spy.fetchCalled)
    }

    func testUpdate_callsPresenterPresentUpdate() {
        let interactor = WorldMapInteractor()
        let spy = SpyWorldMapPresenter()
        interactor.presenter = spy
        interactor.update(WorldMapModels.Update.Request())
        XCTAssertTrue(spy.updateCalled)
    }
}

// MARK: - ProgressDashboardInteractorTests

@MainActor
final class ProgressDashboardInteractorTests: XCTestCase {

    func testFetch_callsPresenterPresentFetch() {
        let interactor = ProgressDashboardInteractor()
        let spy = SpyProgressDashboardPresenter()
        interactor.presenter = spy
        interactor.fetch(ProgressDashboardModels.Fetch.Request())
        XCTAssertTrue(spy.fetchCalled)
    }

    func testUpdate_callsPresenterPresentUpdate() {
        let interactor = ProgressDashboardInteractor()
        let spy = SpyProgressDashboardPresenter()
        interactor.presenter = spy
        interactor.update(ProgressDashboardModels.Update.Request())
        XCTAssertTrue(spy.updateCalled)
    }
}

// MARK: - SessionCompleteInteractorTests

@MainActor
final class SessionCompleteInteractorTests: XCTestCase {

    func testFetch_callsPresenterPresentFetch() {
        let interactor = SessionCompleteInteractor()
        let spy = SpySessionCompletePresenter()
        interactor.presenter = spy
        interactor.fetch(SessionCompleteModels.Fetch.Request())
        XCTAssertTrue(spy.fetchCalled)
    }

    func testUpdate_callsPresenterPresentUpdate() {
        let interactor = SessionCompleteInteractor()
        let spy = SpySessionCompletePresenter()
        interactor.presenter = spy
        interactor.update(SessionCompleteModels.Update.Request())
        XCTAssertTrue(spy.updateCalled)
    }
}

// MARK: - RewardsInteractorTests

@MainActor
final class RewardsInteractorTests: XCTestCase {

    func testFetch_callsPresenterPresentFetch() {
        let interactor = RewardsInteractor()
        let spy = SpyRewardsPresenter()
        interactor.presenter = spy
        interactor.fetch(RewardsModels.Fetch.Request())
        XCTAssertTrue(spy.fetchCalled)
    }

    func testUpdate_callsPresenterPresentUpdate() {
        let interactor = RewardsInteractor()
        let spy = SpyRewardsPresenter()
        interactor.presenter = spy
        interactor.update(RewardsModels.Update.Request())
        XCTAssertTrue(spy.updateCalled)
    }
}

// MARK: - DemoInteractorTests

@MainActor
final class DemoInteractorTests: XCTestCase {

    func testFetch_callsPresenterPresentFetch() {
        let interactor = DemoInteractor()
        let spy = SpyDemoPresenter()
        interactor.presenter = spy
        interactor.fetch(DemoModels.Fetch.Request())
        XCTAssertTrue(spy.fetchCalled)
    }

    func testUpdate_callsPresenterPresentUpdate() {
        let interactor = DemoInteractor()
        let spy = SpyDemoPresenter()
        interactor.presenter = spy
        interactor.update(DemoModels.Update.Request())
        XCTAssertTrue(spy.updateCalled)
    }
}

// MARK: - HomeTasksInteractorTests

@MainActor
final class HomeTasksInteractorTests: XCTestCase {

    func testFetch_callsPresenterPresentFetch() {
        let interactor = HomeTasksInteractor()
        let spy = SpyHomeTasksPresenter()
        interactor.presenter = spy
        interactor.fetch(HomeTasksModels.Fetch.Request())
        XCTAssertTrue(spy.fetchCalled)
    }

    func testUpdate_callsPresenterPresentUpdate() {
        let interactor = HomeTasksInteractor()
        let spy = SpyHomeTasksPresenter()
        interactor.presenter = spy
        interactor.update(HomeTasksModels.Update.Request())
        XCTAssertTrue(spy.updateCalled)
    }
}

// MARK: - ARZoneInteractorTests

@MainActor
final class ARZoneInteractorTests: XCTestCase {

    func testFetch_callsPresenterPresentFetch() {
        let interactor = ARZoneInteractor()
        let spy = SpyARZonePresenter()
        interactor.presenter = spy
        interactor.fetch(ARZoneModels.Fetch.Request())
        XCTAssertTrue(spy.fetchCalled)
    }

    func testUpdate_callsPresenterPresentUpdate() {
        let interactor = ARZoneInteractor()
        let spy = SpyARZonePresenter()
        interactor.presenter = spy
        interactor.update(ARZoneModels.Update.Request())
        XCTAssertTrue(spy.updateCalled)
    }
}

// MARK: - OfflineStateInteractorTests

@MainActor
final class OfflineStateInteractorTests: XCTestCase {

    func testFetch_callsPresenterPresentFetch() {
        let interactor = OfflineStateInteractor()
        let spy = SpyOfflineStatePresenter()
        interactor.presenter = spy
        interactor.fetch(OfflineStateModels.Fetch.Request())
        XCTAssertTrue(spy.fetchCalled)
    }

    func testUpdate_callsPresenterPresentUpdate() {
        let interactor = OfflineStateInteractor()
        let spy = SpyOfflineStatePresenter()
        interactor.presenter = spy
        interactor.update(OfflineStateModels.Update.Request())
        XCTAssertTrue(spy.updateCalled)
    }
}

// MARK: - SpecialistInteractorTests

@MainActor
final class SpecialistInteractorTests: XCTestCase {

    func testFetch_callsPresenterPresentFetch() {
        let interactor = SpecialistInteractor()
        let spy = SpySpecialistPresenter()
        interactor.presenter = spy
        interactor.fetch(SpecialistModels.Fetch.Request())
        XCTAssertTrue(spy.fetchCalled)
    }

    func testUpdate_callsPresenterPresentUpdate() {
        let interactor = SpecialistInteractor()
        let spy = SpySpecialistPresenter()
        interactor.presenter = spy
        interactor.update(SpecialistModels.Update.Request())
        XCTAssertTrue(spy.updateCalled)
    }
}

// MARK: - SessionHistoryInteractorTests

@MainActor
final class SessionHistoryInteractorTests: XCTestCase {

    func testFetch_callsPresenterPresentFetch() {
        let interactor = SessionHistoryInteractor()
        let spy = SpySessionHistoryPresenter()
        interactor.presenter = spy
        interactor.fetch(SessionHistoryModels.Fetch.Request())
        XCTAssertTrue(spy.fetchCalled)
    }

    func testUpdate_callsPresenterPresentUpdate() {
        let interactor = SessionHistoryInteractor()
        let spy = SpySessionHistoryPresenter()
        interactor.presenter = spy
        interactor.update(SessionHistoryModels.Update.Request())
        XCTAssertTrue(spy.updateCalled)
    }
}

// MARK: - PermissionsInteractorTests

@MainActor
final class PermissionsInteractorTests: XCTestCase {

    func testFetch_callsPresenterPresentFetch() {
        let interactor = PermissionsInteractor()
        let spy = SpyPermissionsPresenter()
        interactor.presenter = spy
        interactor.fetch(PermissionsModels.Fetch.Request())
        XCTAssertTrue(spy.fetchCalled)
    }

    func testUpdate_callsPresenterPresentUpdate() {
        let interactor = PermissionsInteractor()
        let spy = SpyPermissionsPresenter()
        interactor.presenter = spy
        interactor.update(PermissionsModels.Update.Request())
        XCTAssertTrue(spy.updateCalled)
    }
}
