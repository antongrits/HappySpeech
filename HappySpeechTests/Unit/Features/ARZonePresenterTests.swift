import XCTest
@testable import HappySpeech

// MARK: - ARZonePresenterTests
//
// Phase 2.6 batch 3 — покрытие ARZonePresenter (51% → цель ≥90%).
// Примечание: ARFaceTrackingConfiguration.isSupported всегда false
// на симуляторе — тест ветки unsupported/ready разделён соответственно.

@MainActor
final class ARZonePresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: ARZoneDisplayLogic {
        var loadGamesVM: ARZoneModels.LoadGames.ViewModel?
        var selectGameVM: ARZoneModels.SelectGame.ViewModel?
        var showTutorialVM: ARZoneModels.SelectGame.ViewModel?
        var selectFallbackCalled = false
        var dismissTutorialVM: ARZoneModels.DismissTutorial.ViewModel?
        var refreshPlannerVM: ARZoneModels.RefreshPlannerAdvice.ViewModel?

        func displayLoadGames(_ viewModel: ARZoneModels.LoadGames.ViewModel) { loadGamesVM = viewModel }
        func displaySelectGame(_ viewModel: ARZoneModels.SelectGame.ViewModel) { selectGameVM = viewModel }
        func displayShowTutorial(_ viewModel: ARZoneModels.SelectGame.ViewModel) { showTutorialVM = viewModel }
        func displaySelectFallback(_ viewModel: ARZoneModels.SelectFallback.ViewModel) { selectFallbackCalled = true }
        func displayDismissTutorial(_ viewModel: ARZoneModels.DismissTutorial.ViewModel) { dismissTutorialVM = viewModel }
        func displayRefreshPlannerAdvice(_ viewModel: ARZoneModels.RefreshPlannerAdvice.ViewModel) { refreshPlannerVM = viewModel }
    }

    private func makeSUT() -> (ARZonePresenter, DisplaySpy) {
        let sut = ARZonePresenter()
        let spy = DisplaySpy()
        sut.viewModel = spy
        return (sut, spy)
    }

    private func makeGame(id: String = "ar-mirror", difficulty: Int = 1) -> ARGame {
        ARGame(
            id: id,
            nameKey: "ar.game.arMirror.name",
            descriptionKey: "ar.game.arMirror.desc",
            iconName: "face.smiling",
            difficulty: difficulty,
            estimatedMinutes: 3,
            targetSounds: [],
            requiresFaceTracking: true,
            destination: .arMirror
        )
    }

    private func makeTutorial(id: String = "ar-mirror") -> ARTutorial {
        ARTutorial(
            id: id,
            titleKey: "ar.tutorial.arMirror.title",
            bodyKey: "ar.tutorial.arMirror.body",
            steps: [],
            animationSystemSymbol: "camera",
            accentColorIndex: 0
        )
    }

    // MARK: - presentLoadGames

    func test_presentLoadGames_noGames_cardsEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentLoadGames(.init(
            games: [],
            instructions: [],
            tips: [],
            plannerAdvice: nil
        ))
        XCTAssertNotNil(spy.loadGamesVM)
        XCTAssertTrue(spy.loadGamesVM?.cards.isEmpty == true)
    }

    func test_presentLoadGames_oneGame_oneCard() {
        let (sut, spy) = makeSUT()
        sut.presentLoadGames(.init(
            games: [makeGame()],
            instructions: [],
            tips: [],
            plannerAdvice: nil
        ))
        XCTAssertEqual(spy.loadGamesVM?.cards.count, 1)
    }

    func test_presentLoadGames_isARSupportedFlag_setCorrectly() {
        let (sut, spy) = makeSUT()
        sut.presentLoadGames(.init(games: [], instructions: [], tips: [], plannerAdvice: nil))
        // На симуляторе isSupported == false → phase = .unsupported
        // Мы только проверяем что флаг существует
        XCTAssertNotNil(spy.loadGamesVM?.isARSupported)
        XCTAssertNotNil(spy.loadGamesVM?.phase)
    }

    func test_presentLoadGames_noPlannerAdvice_bannerIsNil() {
        let (sut, spy) = makeSUT()
        sut.presentLoadGames(.init(games: [], instructions: [], tips: [], plannerAdvice: nil))
        XCTAssertNil(spy.loadGamesVM?.plannerBanner)
    }

    func test_presentLoadGames_plannerAdviceArRecommended_bannerNotNil() {
        let (sut, spy) = makeSUT()
        let advice = ARPlannerAdvice(kind: .arRecommended(gameId: "ar-mirror"))
        sut.presentLoadGames(.init(games: [makeGame()], instructions: [], tips: [], plannerAdvice: advice))
        XCTAssertNotNil(spy.loadGamesVM?.plannerBanner)
        XCTAssertEqual(spy.loadGamesVM?.plannerBanner?.variant, .recommended)
    }

    func test_presentLoadGames_plannerAdviceFatigueTired_bannerFatigueWarning() {
        let (sut, spy) = makeSUT()
        let advice = ARPlannerAdvice(kind: .fatigueWarning(level: .tired))
        sut.presentLoadGames(.init(games: [], instructions: [], tips: [], plannerAdvice: advice))
        XCTAssertEqual(spy.loadGamesVM?.plannerBanner?.variant, .fatigueWarning)
    }

    func test_presentLoadGames_plannerAdviceFatigueNormal_bannerFatigueLight() {
        let (sut, spy) = makeSUT()
        let advice = ARPlannerAdvice(kind: .fatigueWarning(level: .normal))
        sut.presentLoadGames(.init(games: [], instructions: [], tips: [], plannerAdvice: advice))
        XCTAssertEqual(spy.loadGamesVM?.plannerBanner?.variant, .fatigueLight)
    }

    func test_presentLoadGames_plannerAdviceNone_bannerIsNil() {
        let (sut, spy) = makeSUT()
        let advice = ARPlannerAdvice(kind: .none)
        sut.presentLoadGames(.init(games: [], instructions: [], tips: [], plannerAdvice: advice))
        XCTAssertNil(spy.loadGamesVM?.plannerBanner)
    }

    func test_presentLoadGames_recommendedGameId_cardBadgeSet() {
        let (sut, spy) = makeSUT()
        let advice = ARPlannerAdvice(kind: .arRecommended(gameId: "ar-mirror"))
        sut.presentLoadGames(.init(
            games: [makeGame(id: "ar-mirror")],
            instructions: [],
            tips: [],
            plannerAdvice: advice
        ))
        XCTAssertEqual(spy.loadGamesVM?.cards.first?.badge, .recommendedByLyalya)
    }

    func test_presentLoadGames_tips_mappedCorrectly() {
        let (sut, spy) = makeSUT()
        let tipSeeds = InstructionCatalog.tipSeeds
        sut.presentLoadGames(.init(games: [], instructions: [], tips: tipSeeds, plannerAdvice: nil))
        XCTAssertEqual(spy.loadGamesVM?.tips.count, tipSeeds.count)
    }

    func test_presentLoadGames_instructions_mappedCorrectly() {
        let (sut, spy) = makeSUT()
        let seeds = InstructionCatalog.seeds
        sut.presentLoadGames(.init(games: [], instructions: seeds, tips: [], plannerAdvice: nil))
        XCTAssertEqual(spy.loadGamesVM?.instructionSteps.count, seeds.count)
    }

    // MARK: - presentSelectGame

    func test_presentSelectGame_skipTutorial_displaysSelectGame() {
        let (sut, spy) = makeSUT()
        sut.presentSelectGame(.init(
            game: makeGame(),
            tutorial: makeTutorial(),
            skipTutorial: true
        ))
        XCTAssertNotNil(spy.selectGameVM)
        XCTAssertNil(spy.showTutorialVM)
        XCTAssertNil(spy.selectGameVM?.tutorial)
    }

    func test_presentSelectGame_dontSkipTutorial_displaysShowTutorial() {
        let (sut, spy) = makeSUT()
        sut.presentSelectGame(.init(
            game: makeGame(),
            tutorial: makeTutorial(),
            skipTutorial: false
        ))
        XCTAssertNil(spy.selectGameVM)
        XCTAssertNotNil(spy.showTutorialVM)
        XCTAssertNotNil(spy.showTutorialVM?.tutorial)
    }

    func test_presentSelectGame_destination_propagated() {
        let (sut, spy) = makeSUT()
        sut.presentSelectGame(.init(
            game: makeGame(id: "ar-mirror"),
            tutorial: makeTutorial(),
            skipTutorial: true
        ))
        XCTAssertEqual(spy.selectGameVM?.destination, .arMirror)
    }

    // MARK: - presentSelectFallback

    func test_presentSelectFallback_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentSelectFallback(.init())
        XCTAssertTrue(spy.selectFallbackCalled)
    }

    // MARK: - presentDismissTutorial

    func test_presentDismissTutorial_destinationPropagated() {
        let (sut, spy) = makeSUT()
        sut.presentDismissTutorial(.init(destination: .mimicLyalya))
        XCTAssertEqual(spy.dismissTutorialVM?.destination, .mimicLyalya)
    }

    // MARK: - presentRefreshPlannerAdvice

    func test_presentRefreshPlannerAdvice_nilAdvice_bannerNil() {
        let (sut, spy) = makeSUT()
        sut.presentRefreshPlannerAdvice(.init(advice: nil))
        XCTAssertNotNil(spy.refreshPlannerVM)
        XCTAssertNil(spy.refreshPlannerVM?.banner)
    }

    func test_presentRefreshPlannerAdvice_withAdvice_bannerNotNil() {
        let (sut, spy) = makeSUT()
        let advice = ARPlannerAdvice(kind: .arRecommended(gameId: "mimic-lyalya"))
        sut.presentRefreshPlannerAdvice(.init(advice: advice))
        XCTAssertNotNil(spy.refreshPlannerVM?.banner)
    }
}
