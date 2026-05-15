@testable import HappySpeech
import XCTest

// MARK: - Spy Presenter

@MainActor
private final class SpyARActivityPresenter: ARActivityPresentationLogic {
    var loadActivityCallCount = 0
    var requestPermissionCallCount = 0
    var selectGameCallCount = 0
    var startActivityCallCount = 0
    var completeActivityCallCount = 0

    var lastLoadActivity: ARActivityModels.LoadActivity.Response?
    var lastRequestPermission: ARActivityModels.RequestPermission.Response?
    var lastSelectGame: ARActivityModels.SelectGame.Response?
    var lastStartActivity: ARActivityModels.StartActivity.Response?
    var lastCompleteActivity: ARActivityModels.CompleteActivity.Response?

    func presentLoadActivity(_ response: ARActivityModels.LoadActivity.Response) {
        loadActivityCallCount += 1
        lastLoadActivity = response
    }
    func presentRequestPermission(
        _ response: ARActivityModels.RequestPermission.Response,
        cards: [ARActivityGameCard]
    ) {
        requestPermissionCallCount += 1
        lastRequestPermission = response
    }
    func presentSelectGame(_ response: ARActivityModels.SelectGame.Response) {
        selectGameCallCount += 1
        lastSelectGame = response
    }
    func presentStartActivity(_ response: ARActivityModels.StartActivity.Response) {
        startActivityCallCount += 1
        lastStartActivity = response
    }
    func presentCompleteActivity(_ response: ARActivityModels.CompleteActivity.Response) {
        completeActivityCallCount += 1
        lastCompleteActivity = response
    }
}

// MARK: - Spy Router

@MainActor
private final class SpyARActivityRouter: ARActivityRoutingLogic {
    var routedDestinations: [String] = []

    func routeToARMirror() { routedDestinations.append("mirror") }
    func routeToARStoryQuest() { routedDestinations.append("storyQuest") }
    func routeToButterflyCatch() { routedDestinations.append("butterfly") }
    func routeToBreathingAR() { routedDestinations.append("breathing") }
    func routeToMimicLyalya() { routedDestinations.append("mimic") }
    func routeToHoldThePose() { routedDestinations.append("holdPose") }
    func routeToPoseSequence() { routedDestinations.append("poseSequence") }
    func routeToSoundAndFace() { routedDestinations.append("soundFace") }
    func routeToSystemSettings() { routedDestinations.append("settings") }
    func dismiss() { routedDestinations.append("dismiss") }
}

// MARK: - Tests
//
// ARActivityInteractor — диспетчер AR-игр.
//
// Заметка о покрытии AR-кода:
// `detectCapabilities()`, `currentCameraPermission()`, `requestCameraPermission()`
// зависят от ARKit / AVFoundation hardware API. На симуляторе ARFaceTracking
// не поддержан, права камеры запрашиваются системой — поэтому ветки реальных
// разрешений не детерминированы. Тесты покрывают: диспетчеризацию игр,
// smart-routing, scoring/stars, completion-сообщения, legacy startActivity
// и `resolveActivityType`. `loadActivity` проверяется на факт построения карточек.

@MainActor
final class ARActivityInteractorTests: XCTestCase {

    private func makeSUT() -> (
        ARActivityInteractor,
        SpyARActivityPresenter,
        SpyARActivityRouter,
        SpySessionRepository,
        SpyAdaptivePlannerService
    ) {
        let sessionRepo = SpySessionRepository(sessions: [])
        let planner = SpyAdaptivePlannerService()
        let sut = ARActivityInteractor(
            adaptivePlanner: planner,
            sessionRepository: sessionRepo,
            hapticService: MockHapticService()
        )
        let presenter = SpyARActivityPresenter()
        let router = SpyARActivityRouter()
        sut.presenter = presenter
        sut.router = router
        return (sut, presenter, router, sessionRepo, planner)
    }

    /// Ожидает, пока async `loadActivity` опубликует ответ presenter'у.
    /// `performLoad` обращается к ARKit/AVAudioSession — первый вызов может быть медленным.
    private func waitForLoad(_ presenter: SpyARActivityPresenter, timeout: TimeInterval = 8) async {
        let deadline = Date().addingTimeInterval(timeout)
        while presenter.loadActivityCallCount == 0, Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func loadRequest(
        soundGroup: String = "sonants",
        targetSound: String = "Р",
        stage: String = "wordInit"
    ) -> ARActivityModels.LoadActivity.Request {
        ARActivityModels.LoadActivity.Request(
            contentUnitId: "unit-1",
            soundGroup: soundGroup,
            targetSound: targetSound,
            stage: stage,
            childName: "Маша",
            childId: "child-1",
            childAge: 6
        )
    }

    // MARK: - loadActivity

    func test_loadActivity_buildsSevenGameCards() async {
        let (sut, presenter, _, _, _) = makeSUT()
        sut.loadActivity(loadRequest())
        await waitForLoad(presenter)
        XCTAssertEqual(presenter.loadActivityCallCount, 1)
        XCTAssertEqual(presenter.lastLoadActivity?.gameCards.count, ARGameKind.allCases.count)
    }

    func test_loadActivity_passesTargetSoundAndChildName() async {
        let (sut, presenter, _, _, _) = makeSUT()
        sut.loadActivity(loadRequest(targetSound: "Ш"))
        await waitForLoad(presenter)
        XCTAssertEqual(presenter.lastLoadActivity?.targetSound, "Ш")
        XCTAssertEqual(presenter.lastLoadActivity?.childName, "Маша")
    }

    func test_loadActivity_recommendsGameForSoundGroup() async {
        let (sut, presenter, _, _, _) = makeSUT()
        sut.loadActivity(loadRequest(soundGroup: "sonants"))
        await waitForLoad(presenter)
        // Соноры рекомендуют arMirror (или fallback butterflyCatch без faceTracking)
        XCTAssertNotNil(presenter.lastLoadActivity?.recommendedKind)
    }

    // MARK: - selectGame routing

    func test_selectGame_routesToCorrectScreen() {
        let cases: [(ARGameKind, String)] = [
            (.arMirror, "mirror"),
            (.butterflyCatch, "butterfly"),
            (.breathingAR, "breathing"),
            (.mimicLyalya, "mimic"),
            (.holdThePose, "holdPose"),
            (.poseSequence, "poseSequence"),
            (.soundAndFace, "soundFace")
        ]
        for (kind, expected) in cases {
            let (sut, presenter, router, _, _) = makeSUT()
            sut.selectGame(.init(kind: kind))
            XCTAssertEqual(presenter.lastSelectGame?.kind, kind)
            XCTAssertTrue(router.routedDestinations.contains(expected), "Игра \(kind) → \(expected)")
        }
    }

    func test_selectGame_emitsSelectResponse() {
        let (sut, presenter, _, _, _) = makeSUT()
        sut.selectGame(.init(kind: .arMirror))
        XCTAssertEqual(presenter.selectGameCallCount, 1)
        XCTAssertEqual(presenter.lastSelectGame?.kind, .arMirror)
    }

    // MARK: - startActivity (legacy)

    func test_startActivity_mirror_routesToMirror() {
        let (sut, presenter, router, _, _) = makeSUT()
        sut.startActivity(.init(activityType: .mirror))
        XCTAssertEqual(presenter.lastStartActivity?.activityType, .mirror)
        XCTAssertTrue(router.routedDestinations.contains("mirror"))
    }

    func test_startActivity_storyQuest_routesToStoryQuest() {
        let (sut, presenter, router, _, _) = makeSUT()
        sut.startActivity(.init(activityType: .storyQuest))
        XCTAssertEqual(presenter.lastStartActivity?.activityType, .storyQuest)
        XCTAssertTrue(router.routedDestinations.contains("storyQuest"))
    }

    // MARK: - completeActivity stars & messages

    func test_completeActivity_perfectScore_threeStars() {
        let (sut, presenter, _, _, _) = makeSUT()
        sut.completeActivity(.init(
            activityType: .mirror, gameKind: .arMirror, score: 0.95, attempts: 10, durationSec: 120
        ))
        XCTAssertEqual(presenter.lastCompleteActivity?.starsEarned, 3)
        XCTAssertFalse(presenter.lastCompleteActivity?.message.isEmpty ?? true)
    }

    func test_completeActivity_goodScore_twoStars() {
        let (sut, presenter, _, _, _) = makeSUT()
        sut.completeActivity(.init(
            activityType: .mirror, gameKind: .arMirror, score: 0.75, attempts: 10, durationSec: 120
        ))
        XCTAssertEqual(presenter.lastCompleteActivity?.starsEarned, 2)
    }

    func test_completeActivity_lowScore_oneStar() {
        let (sut, presenter, _, _, _) = makeSUT()
        sut.completeActivity(.init(
            activityType: .mirror, gameKind: .arMirror, score: 0.55, attempts: 10, durationSec: 120
        ))
        XCTAssertEqual(presenter.lastCompleteActivity?.starsEarned, 1)
    }

    func test_completeActivity_veryLowScore_zeroStars() {
        let (sut, presenter, _, _, _) = makeSUT()
        sut.completeActivity(.init(
            activityType: .mirror, gameKind: .arMirror, score: 0.2, attempts: 10, durationSec: 120
        ))
        XCTAssertEqual(presenter.lastCompleteActivity?.starsEarned, 0)
    }

    func test_completeActivity_scoreClampedAboveOne() {
        let (sut, presenter, _, _, _) = makeSUT()
        sut.completeActivity(.init(
            activityType: .mirror, gameKind: .arMirror, score: 5.0, attempts: 1, durationSec: 60
        ))
        XCTAssertEqual(presenter.lastCompleteActivity?.starsEarned, 3)
    }

    func test_completeActivity_persistsSessionToRepository() async {
        let (sut, presenter, _, sessionRepo, _) = makeSUT()
        // loadActivity сначала, чтобы loadRequest был установлен
        sut.loadActivity(loadRequest())
        await waitForLoad(presenter)
        sut.completeActivity(.init(
            activityType: .mirror, gameKind: .arMirror, score: 0.8, attempts: 5, durationSec: 90
        ))
        // persistARSession выполняется в детачнутом Task
        let deadline = Date().addingTimeInterval(5)
        while sessionRepo.saveCallCount == 0, Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertGreaterThanOrEqual(sessionRepo.saveCallCount, 1)
        XCTAssertEqual(sessionRepo.lastSaved?.childId, "child-1")
        XCTAssertEqual(sessionRepo.lastSaved?.templateType, ARGameKind.arMirror.rawValue)
    }

    func test_completeActivity_withoutLoadRequest_stillEmitsResponse() {
        let (sut, presenter, _, _, _) = makeSUT()
        // Нет loadActivity — loadRequest == nil; запись пропускается, но ответ есть
        sut.completeActivity(.init(
            activityType: .storyQuest, gameKind: nil, score: 0.9, attempts: 3, durationSec: 60
        ))
        XCTAssertEqual(presenter.completeActivityCallCount, 1)
    }

    // MARK: - openSettings

    func test_openSettings_routesToSystemSettings() {
        let (sut, _, router, _, _) = makeSUT()
        sut.openSettings(.init())
        XCTAssertTrue(router.routedDestinations.contains("settings"))
    }

    // MARK: - resolveActivityType (legacy helper)

    func test_resolveActivityType_sonants_returnsMirror() {
        let (sut, _, _, _, _) = makeSUT()
        XCTAssertEqual(sut.resolveActivityType(soundGroup: "sonants", stage: "wordInit"), .mirror)
        XCTAssertEqual(sut.resolveActivityType(soundGroup: "sonorant", stage: "wordInit"), .mirror)
        XCTAssertEqual(sut.resolveActivityType(soundGroup: "velar", stage: "syllable"), .mirror)
    }

    func test_resolveActivityType_whistlingIsolated_returnsMirror() {
        let (sut, _, _, _, _) = makeSUT()
        XCTAssertEqual(sut.resolveActivityType(soundGroup: "whistling", stage: "isolated"), .mirror)
        XCTAssertEqual(sut.resolveActivityType(soundGroup: "hissing", stage: "syllable"), .mirror)
    }

    func test_resolveActivityType_whistlingWord_returnsStoryQuest() {
        let (sut, _, _, _, _) = makeSUT()
        XCTAssertEqual(sut.resolveActivityType(soundGroup: "whistling", stage: "wordInit"), .storyQuest)
    }

    func test_resolveActivityType_unknownGroup_returnsStoryQuest() {
        let (sut, _, _, _, _) = makeSUT()
        XCTAssertEqual(sut.resolveActivityType(soundGroup: "unknown", stage: "wordInit"), .storyQuest)
    }

    // MARK: - ARGameKind metadata

    func test_arGameKind_metadataConsistent() {
        for kind in ARGameKind.allCases {
            XCTAssertFalse(kind.localizedName.isEmpty)
            XCTAssertFalse(kind.localizedDescription.isEmpty)
            XCTAssertFalse(kind.iconSystemName.isEmpty)
            XCTAssertGreaterThan(kind.estimatedDurationSec, 0)
        }
    }

    func test_arGameKind_faceTrackingRequirements() {
        XCTAssertTrue(ARGameKind.arMirror.requiresFaceTracking)
        XCTAssertFalse(ARGameKind.butterflyCatch.requiresFaceTracking)
        XCTAssertFalse(ARGameKind.breathingAR.requiresFaceTracking)
    }

    func test_arGameKind_microphoneRequirements() {
        XCTAssertTrue(ARGameKind.breathingAR.requiresMicrophone)
        XCTAssertTrue(ARGameKind.soundAndFace.requiresMicrophone)
        XCTAssertFalse(ARGameKind.arMirror.requiresMicrophone)
    }

    func test_arActivityType_fromKind() {
        XCTAssertEqual(ARActivityType.from(kind: .arMirror), .mirror)
        XCTAssertEqual(ARActivityType.from(kind: .mimicLyalya), .mirror)
        XCTAssertEqual(ARActivityType.from(kind: .butterflyCatch), .storyQuest)
        XCTAssertEqual(ARActivityType.from(kind: .breathingAR), .storyQuest)
    }
}
