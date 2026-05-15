@testable import HappySpeech
import XCTest

// MARK: - Spy Presenter

@MainActor
private final class SpyARZonePresenter: ARZonePresentationLogic {

    var loadGamesCount = 0
    var selectGameCount = 0
    var selectFallbackCount = 0
    var dismissTutorialCount = 0
    var refreshPlannerAdviceCount = 0

    var loadGamesResponses: [ARZoneModels.LoadGames.Response] = []
    var lastSelectGame: ARZoneModels.SelectGame.Response?
    var lastDismissTutorial: ARZoneModels.DismissTutorial.Response?
    var lastRefreshAdvice: ARZoneModels.RefreshPlannerAdvice.Response?

    func presentLoadGames(_ response: ARZoneModels.LoadGames.Response) {
        loadGamesCount += 1
        loadGamesResponses.append(response)
    }
    func presentSelectGame(_ response: ARZoneModels.SelectGame.Response) {
        selectGameCount += 1
        lastSelectGame = response
    }
    func presentSelectFallback(_ response: ARZoneModels.SelectFallback.Response) {
        selectFallbackCount += 1
    }
    func presentDismissTutorial(_ response: ARZoneModels.DismissTutorial.Response) {
        dismissTutorialCount += 1
        lastDismissTutorial = response
    }
    func presentRefreshPlannerAdvice(_ response: ARZoneModels.RefreshPlannerAdvice.Response) {
        refreshPlannerAdviceCount += 1
        lastRefreshAdvice = response
    }
}

// MARK: - Tests

@MainActor
final class ARZoneInteractorTests: XCTestCase {

    private func makeSUT(
        planner: (any AdaptivePlannerService)? = nil
    ) -> (ARZoneInteractor, SpyARZonePresenter) {
        let sut = ARZoneInteractor()
        sut.plannerService = planner
        let spy = SpyARZonePresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    private func route(fatigue: FatigueLevel, includeAR: Bool) -> AdaptiveRoute {
        var steps: [RouteStepItem] = [
            RouteStepItem(templateType: .listenAndChoose, targetSound: "Р", stage: .wordInit,
                          difficulty: 2, wordCount: 10, durationTargetSec: 180)
        ]
        if includeAR {
            steps.append(RouteStepItem(templateType: .arActivity, targetSound: "Р", stage: .wordInit,
                                       difficulty: 1, wordCount: 6, durationTargetSec: 120))
        }
        return AdaptiveRoute(steps: steps, maxDurationSec: 900, fatigueLevel: fatigue)
    }

    // MARK: - loadGames

    func test_loadGames_emitsImmediateResponse() async {
        let (sut, spy) = makeSUT()
        sut.loadGames(.init(childId: "child-1"))
        // Немедленный рендер без advice.
        XCTAssertGreaterThanOrEqual(spy.loadGamesCount, 1)
        XCTAssertEqual(spy.loadGamesResponses.first?.games.count, ARGameCatalog.all.count)
        XCTAssertNil(spy.loadGamesResponses.first?.plannerAdvice)
    }

    func test_loadGames_withoutPlannerSecondResponseHasNoneAdvice() async {
        let (sut, spy) = makeSUT()
        sut.loadGames(.init(childId: "child-1"))
        // Ждём асинхронную задачу planner-advice.
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertGreaterThanOrEqual(spy.loadGamesCount, 2)
        XCTAssertEqual(spy.loadGamesResponses.last?.plannerAdvice?.kind, ARPlannerAdvice.Kind.none)
    }

    func test_loadGames_emptyChildIdGivesNoneAdvice() async {
        let planner = SpyAdaptivePlannerService(route: route(fatigue: .fresh, includeAR: true))
        let (sut, spy) = makeSUT(planner: planner)
        sut.loadGames(.init(childId: ""))
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(spy.loadGamesResponses.last?.plannerAdvice?.kind, ARPlannerAdvice.Kind.none)
    }

    func test_loadGames_tiredFatigueGivesWarning() async {
        let planner = SpyAdaptivePlannerService(route: route(fatigue: .tired, includeAR: false))
        let (sut, spy) = makeSUT(planner: planner)
        sut.loadGames(.init(childId: "child-1"))
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(spy.loadGamesResponses.last?.plannerAdvice?.kind,
                       .fatigueWarning(level: .tired))
    }

    func test_loadGames_freshWithARRecommendsGame() async {
        let planner = SpyAdaptivePlannerService(route: route(fatigue: .fresh, includeAR: true))
        let (sut, spy) = makeSUT(planner: planner)
        sut.loadGames(.init(childId: "child-1"))
        try? await Task.sleep(nanoseconds: 200_000_000)
        if case .arRecommended = spy.loadGamesResponses.last?.plannerAdvice?.kind {
            // ok — planner рекомендует AR-игру.
        } else {
            XCTFail("Expected .arRecommended advice")
        }
    }

    func test_loadGames_plannerFailureDegradesToNone() async {
        let planner = SpyAdaptivePlannerService()
        planner.shouldFail = true
        let (sut, spy) = makeSUT(planner: planner)
        sut.loadGames(.init(childId: "child-1"))
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(spy.loadGamesResponses.last?.plannerAdvice?.kind, ARPlannerAdvice.Kind.none)
    }

    // MARK: - selectGame

    func test_selectGame_validGameEmitsResponse() {
        let (sut, spy) = makeSUT()
        sut.selectGame(.init(gameId: "ar-mirror", skipTutorial: false))
        XCTAssertEqual(spy.selectGameCount, 1)
        XCTAssertEqual(spy.lastSelectGame?.game.id, "ar-mirror")
        XCTAssertEqual(spy.lastSelectGame?.skipTutorial, false)
    }

    func test_selectGame_unknownGameIsIgnored() {
        let (sut, spy) = makeSUT()
        sut.selectGame(.init(gameId: "nonexistent-game", skipTutorial: false))
        XCTAssertEqual(spy.selectGameCount, 0)
    }

    func test_selectGame_skipTutorialFlagRespected() {
        let (sut, spy) = makeSUT()
        sut.selectGame(.init(gameId: "butterfly-catch", skipTutorial: true))
        XCTAssertEqual(spy.lastSelectGame?.skipTutorial, true)
    }

    func test_selectGame_previouslyPlayedSkipsTutorial() {
        let (sut, spy) = makeSUT()
        // Сначала помечаем игру как сыгранную через dismissTutorial.
        sut.dismissTutorial(.init(destination: .arMirror, action: .start))
        sut.selectGame(.init(gameId: "ar-mirror", skipTutorial: false))
        // Игра уже игралась → tutorial пропускается даже при skipTutorial=false.
        XCTAssertEqual(spy.lastSelectGame?.skipTutorial, true)
    }

    // MARK: - selectFallback

    func test_selectFallback_emitsResponse() {
        let (sut, spy) = makeSUT()
        sut.selectFallback(.init())
        XCTAssertEqual(spy.selectFallbackCount, 1)
    }

    // MARK: - dismissTutorial

    func test_dismissTutorial_startActionEmitsDestination() {
        let (sut, spy) = makeSUT()
        sut.dismissTutorial(.init(destination: .holdThePose, action: .start))
        XCTAssertEqual(spy.dismissTutorialCount, 1)
        XCTAssertEqual(spy.lastDismissTutorial?.destination, .holdThePose)
    }

    func test_dismissTutorial_skipAction() {
        let (sut, spy) = makeSUT()
        sut.dismissTutorial(.init(destination: .butterflyCatch, action: .skip))
        XCTAssertEqual(spy.lastDismissTutorial?.destination, .butterflyCatch)
    }

    func test_dismissTutorial_marksGameAsPlayed() {
        let (sut, spy) = makeSUT()
        sut.dismissTutorial(.init(destination: .soundAndFace, action: .start))
        sut.selectGame(.init(gameId: "sound-and-face", skipTutorial: false))
        XCTAssertEqual(spy.lastSelectGame?.skipTutorial, true)
    }

    // MARK: - refreshPlannerAdvice

    func test_refreshPlannerAdvice_withoutPlannerGivesNone() async {
        let (sut, spy) = makeSUT()
        sut.refreshPlannerAdvice(.init(childId: "child-1"))
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(spy.refreshPlannerAdviceCount, 1)
        XCTAssertEqual(spy.lastRefreshAdvice?.advice?.kind, ARPlannerAdvice.Kind.none)
    }

    func test_refreshPlannerAdvice_tiredGivesWarning() async {
        let planner = SpyAdaptivePlannerService(route: route(fatigue: .tired, includeAR: false))
        let (sut, spy) = makeSUT(planner: planner)
        sut.refreshPlannerAdvice(.init(childId: "child-1"))
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(spy.lastRefreshAdvice?.advice?.kind, .fatigueWarning(level: .tired))
    }

    func test_refreshPlannerAdvice_freshWithARRecommends() async {
        let planner = SpyAdaptivePlannerService(route: route(fatigue: .fresh, includeAR: true))
        let (sut, spy) = makeSUT(planner: planner)
        sut.refreshPlannerAdvice(.init(childId: "child-1"))
        try? await Task.sleep(nanoseconds: 200_000_000)
        if case .arRecommended = spy.lastRefreshAdvice?.advice?.kind {
            // ok
        } else {
            XCTFail("Expected .arRecommended advice")
        }
    }

    // MARK: - ARGameCatalog

    func test_arGameCatalog_lookupById() {
        XCTAssertNotNil(ARGameCatalog.game(id: "ar-mirror"))
        XCTAssertNil(ARGameCatalog.game(id: "missing"))
    }

    func test_arGameCatalog_lookupByDestination() {
        XCTAssertEqual(ARGameCatalog.game(forDestination: .arMirror)?.id, "ar-mirror")
        XCTAssertEqual(ARGameCatalog.game(forDestination: .arStoryQuest)?.id, "ar-story-quest")
    }

    func test_arGameCatalog_hasEightGames() {
        XCTAssertEqual(ARGameCatalog.all.count, 8)
    }
}
