@testable import HappySpeech
import XCTest

// MARK: - ARActivityPresenterTests
//
// Phase 2.6.1 v25 — покрытие ARActivityPresenter (13 тестов).
// Тестируются все 5 методов: presentLoadActivity, presentRequestPermission,
// presentSelectGame, presentStartActivity, presentCompleteActivity.

@MainActor
final class ARActivityPresenterTests: XCTestCase {

    // MARK: - DisplaySpy

    @MainActor
    private final class DisplaySpy: ARActivityDisplayLogic {
        var loadActivityVM: ARActivityModels.LoadActivity.ViewModel?
        var requestPermissionVM: ARActivityModels.RequestPermission.ViewModel?
        var requestPermissionCards: [ARActivityGameCard]?
        var selectGameVM: ARActivityModels.SelectGame.ViewModel?
        var startActivityVM: ARActivityModels.StartActivity.ViewModel?
        var completeActivityVM: ARActivityModels.CompleteActivity.ViewModel?

        func displayLoadActivity(_ viewModel: ARActivityModels.LoadActivity.ViewModel) { loadActivityVM = viewModel }
        func displayRequestPermission(_ viewModel: ARActivityModels.RequestPermission.ViewModel, cards: [ARActivityGameCard]) {
            requestPermissionVM = viewModel
            requestPermissionCards = cards
        }
        func displaySelectGame(_ viewModel: ARActivityModels.SelectGame.ViewModel) { selectGameVM = viewModel }
        func displayStartActivity(_ viewModel: ARActivityModels.StartActivity.ViewModel) { startActivityVM = viewModel }
        func displayCompleteActivity(_ viewModel: ARActivityModels.CompleteActivity.ViewModel) { completeActivityVM = viewModel }
    }

    private func makeSUT() -> (ARActivityPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = ARActivityPresenter()
        presenter.viewModel = spy
        return (presenter, spy)
    }

    private func makeCapability() -> ARCapabilityState {
        ARCapabilityState(supportsFaceTracking: true, supportsWorldTracking: true, supportsMicrophone: true)
    }

    private func makeCard(kind: ARGameKind = .arMirror, isAvailable: Bool = true) -> ARActivityGameCard {
        ARActivityGameCard(
            id: kind.rawValue,
            kind: kind,
            title: kind.localizedName,
            description: kind.localizedDescription,
            iconSystemName: kind.iconSystemName,
            estimatedLabel: "3 мин",
            isRecommended: false,
            isAvailable: isAvailable,
            unavailableReason: "",
            playedToday: false
        )
    }

    // MARK: - presentLoadActivity

    func test_presentLoadActivity_withTargetSound_subtitleContainsSound() {
        let (sut, spy) = makeSUT()
        let response = ARActivityModels.LoadActivity.Response(
            capability: makeCapability(),
            cameraPermission: .authorized,
            microphonePermission: .authorized,
            gameCards: [makeCard()],
            recommendedKind: nil,
            targetSound: "Р",
            childName: "Ваня"
        )
        sut.presentLoadActivity(response)
        XCTAssertNotNil(spy.loadActivityVM)
        XCTAssertTrue(spy.loadActivityVM?.subtitle.contains("Р") ?? false)
        XCTAssertFalse(spy.loadActivityVM?.showPermissionBanner ?? true)
    }

    func test_presentLoadActivity_emptyTargetSound_defaultSubtitle() {
        let (sut, spy) = makeSUT()
        let response = ARActivityModels.LoadActivity.Response(
            capability: makeCapability(),
            cameraPermission: .authorized,
            microphonePermission: .authorized,
            gameCards: [],
            recommendedKind: nil,
            targetSound: "",
            childName: ""
        )
        sut.presentLoadActivity(response)
        XCTAssertFalse(spy.loadActivityVM?.subtitle.isEmpty ?? true)
        XCTAssertFalse(spy.loadActivityVM?.hasAnyAvailableGame ?? true)
    }

    func test_presentLoadActivity_cameraDenied_showsBanner() {
        let (sut, spy) = makeSUT()
        let response = ARActivityModels.LoadActivity.Response(
            capability: makeCapability(),
            cameraPermission: .denied,
            microphonePermission: .authorized,
            gameCards: [makeCard()],
            recommendedKind: nil,
            targetSound: "Ш",
            childName: "Катя"
        )
        sut.presentLoadActivity(response)
        XCTAssertTrue(spy.loadActivityVM?.showPermissionBanner ?? false)
        XCTAssertFalse(spy.loadActivityVM?.permissionBannerMessage.isEmpty ?? true)
    }

    func test_presentLoadActivity_cameraNotDetermined_showsBanner() {
        let (sut, spy) = makeSUT()
        let response = ARActivityModels.LoadActivity.Response(
            capability: makeCapability(),
            cameraPermission: .notDetermined,
            microphonePermission: .notDetermined,
            gameCards: [],
            recommendedKind: nil,
            targetSound: "",
            childName: ""
        )
        sut.presentLoadActivity(response)
        XCTAssertTrue(spy.loadActivityVM?.showPermissionBanner ?? false)
    }

    func test_presentLoadActivity_hasAvailableCards_hasAnyAvailableTrue() {
        let (sut, spy) = makeSUT()
        let response = ARActivityModels.LoadActivity.Response(
            capability: makeCapability(),
            cameraPermission: .authorized,
            microphonePermission: .authorized,
            gameCards: [makeCard(isAvailable: true), makeCard(kind: .breathingAR, isAvailable: false)],
            recommendedKind: nil,
            targetSound: "",
            childName: ""
        )
        sut.presentLoadActivity(response)
        XCTAssertTrue(spy.loadActivityVM?.hasAnyAvailableGame ?? false)
    }

    // MARK: - presentRequestPermission

    func test_presentRequestPermission_cameraGranted_authorizedCam() {
        let (sut, spy) = makeSUT()
        let response = ARActivityModels.RequestPermission.Response(kind: .camera, granted: true)
        sut.presentRequestPermission(response, cards: [makeCard()])
        XCTAssertEqual(spy.requestPermissionVM?.cameraPermission, .authorized)
        XCTAssertFalse(spy.requestPermissionVM?.showPermissionBanner ?? true)
    }

    func test_presentRequestPermission_cameraDenied_showsBanner() {
        let (sut, spy) = makeSUT()
        let response = ARActivityModels.RequestPermission.Response(kind: .camera, granted: false)
        sut.presentRequestPermission(response, cards: [])
        XCTAssertEqual(spy.requestPermissionVM?.cameraPermission, .denied)
        XCTAssertTrue(spy.requestPermissionVM?.showPermissionBanner ?? false)
        XCTAssertFalse(spy.requestPermissionVM?.permissionBannerMessage.isEmpty ?? true)
    }

    func test_presentRequestPermission_micGranted_authorizedMic() {
        let (sut, spy) = makeSUT()
        let response = ARActivityModels.RequestPermission.Response(kind: .microphone, granted: true)
        sut.presentRequestPermission(response, cards: [])
        XCTAssertEqual(spy.requestPermissionVM?.microphonePermission, .authorized)
    }

    // MARK: - presentSelectGame

    func test_presentSelectGame_passesKindThrough() {
        let (sut, spy) = makeSUT()
        sut.presentSelectGame(ARActivityModels.SelectGame.Response(kind: .mimicLyalya))
        XCTAssertEqual(spy.selectGameVM?.kind, .mimicLyalya)
    }

    // MARK: - presentStartActivity

    func test_presentStartActivity_mirrorActivity_passedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentStartActivity(ARActivityModels.StartActivity.Response(activityType: .mirror))
        XCTAssertEqual(spy.startActivityVM?.activityType, .mirror)
    }

    // MARK: - presentCompleteActivity

    func test_presentCompleteActivity_highScore_scoreLabelContainsPercent() {
        let (sut, spy) = makeSUT()
        let response = ARActivityModels.CompleteActivity.Response(
            score: 0.9,
            starsEarned: 3,
            message: "Отлично!",
            gameKind: .arMirror
        )
        sut.presentCompleteActivity(response)
        XCTAssertEqual(spy.completeActivityVM?.starsEarned, 3)
        XCTAssertTrue(spy.completeActivityVM?.scoreLabel.contains("%") ?? false)
        XCTAssertEqual(spy.completeActivityVM?.message, "Отлично!")
    }

    func test_presentCompleteActivity_zeroScore_scoreLabelNotEmpty() {
        let (sut, spy) = makeSUT()
        let response = ARActivityModels.CompleteActivity.Response(
            score: 0.0,
            starsEarned: 0,
            message: "Попробуй ещё раз",
            gameKind: nil
        )
        sut.presentCompleteActivity(response)
        XCTAssertFalse(spy.completeActivityVM?.scoreLabel.isEmpty ?? true)
        XCTAssertEqual(spy.completeActivityVM?.starsEarned, 0)
    }

    func test_presentCompleteActivity_passesScoreThrough() {
        let (sut, spy) = makeSUT()
        let response = ARActivityModels.CompleteActivity.Response(
            score: 0.75,
            starsEarned: 2,
            message: "Хорошо!",
            gameKind: .breathingAR
        )
        sut.presentCompleteActivity(response)
        XCTAssertEqual(spy.completeActivityVM?.score ?? 0, 0.75, accuracy: 0.001)
    }
}
