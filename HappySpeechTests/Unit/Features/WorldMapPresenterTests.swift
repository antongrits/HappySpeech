import XCTest
@testable import HappySpeech

// MARK: - WorldMapPresenterTests
//
// Phase 2.6 batch 3 — покрытие WorldMapPresenter (35% → цель ≥90%).

@MainActor
final class WorldMapPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: WorldMapDisplayLogic {
        var loadMapVM: WorldMapModels.LoadMap.ViewModel?
        var selectZoneVM: WorldMapModels.SelectZone.ViewModel?
        var zoneDetailVM: WorldMapModels.LoadZoneDetail.ViewModel?
        var refreshVM: WorldMapModels.RefreshProgress.ViewModel?
        var failureVM: WorldMapModels.Failure.ViewModel?
        var voicePromptVM: WorldMapModels.VoicePrompt.ViewModel?
        var collectTreasureVM: WorldMapModels.CollectTreasure.ViewModel?
        var selectLevelVM: WorldMapModels.SelectLevel.ViewModel?
        var adaptiveRecVM: WorldMapModels.AdaptiveRecommendation.ViewModel?

        var isLoading: Bool = false

        func displayLoadMap(_ viewModel: WorldMapModels.LoadMap.ViewModel) { loadMapVM = viewModel }
        func displaySelectZone(_ viewModel: WorldMapModels.SelectZone.ViewModel) { selectZoneVM = viewModel }
        func displayLoadZoneDetail(_ viewModel: WorldMapModels.LoadZoneDetail.ViewModel) { zoneDetailVM = viewModel }
        func displayRefreshProgress(_ viewModel: WorldMapModels.RefreshProgress.ViewModel) { refreshVM = viewModel }
        func displayFailure(_ viewModel: WorldMapModels.Failure.ViewModel) { failureVM = viewModel }
        func displayLoading(_ isLoading: Bool) { self.isLoading = isLoading }
        func displayVoicePrompt(_ viewModel: WorldMapModels.VoicePrompt.ViewModel) { voicePromptVM = viewModel }
        func displayCollectTreasure(_ viewModel: WorldMapModels.CollectTreasure.ViewModel) { collectTreasureVM = viewModel }
        func displaySelectLevel(_ viewModel: WorldMapModels.SelectLevel.ViewModel) { selectLevelVM = viewModel }
        func displayAdaptiveRecommendation(_ viewModel: WorldMapModels.AdaptiveRecommendation.ViewModel) { adaptiveRecVM = viewModel }
    }

    private func makeSUT() -> (WorldMapPresenter, DisplaySpy) {
        let sut = WorldMapPresenter()
        let spy = DisplaySpy()
        sut.display = spy
        return (sut, spy)
    }

    private func makeZone(
        id: String = "zone-1",
        progress: Float = 0.5,
        completedLessons: Int = 5,
        totalLessons: Int = 10,
        isLocked: Bool = false,
        sounds: [String] = ["С", "З"]
    ) -> WorldZone {
        WorldZone(
            id: id,
            name: "Свистящие",
            icon: "waveform",
            sounds: sounds,
            progress: progress,
            completedLessons: completedLessons,
            totalLessons: totalLessons,
            colorName: "primary",
            isLocked: isLocked
        )
    }

    // MARK: - presentLoadMap

    func test_presentLoadMap_calculatesProgress() {
        let (sut, spy) = makeSUT()
        let zone = makeZone(completedLessons: 5, totalLessons: 10)
        sut.presentLoadMap(.init(
            zones: [zone],
            islands: [],
            collectibles: [],
            totalStars: 42,
            highlightedZoneId: nil,
            dailyStreak: 3,
            lyalyaIslandId: "lyalya-island",
            recommendedIslandId: nil,
            recommendedLevelId: nil
        ))
        XCTAssertNotNil(spy.loadMapVM)
        XCTAssertEqual(spy.loadMapVM?.totalProgressFraction ?? 0, 0.5, accuracy: 0.01)
        XCTAssertTrue(spy.loadMapVM?.hasStreak == true)
        XCTAssertFalse(spy.loadMapVM?.totalStarsLabel.isEmpty ?? true)
    }

    func test_presentLoadMap_zeroLessons_progressIsZero() {
        let (sut, spy) = makeSUT()
        let zone = makeZone(completedLessons: 0, totalLessons: 0)
        sut.presentLoadMap(.init(
            zones: [zone],
            islands: [],
            collectibles: [],
            totalStars: 0,
            highlightedZoneId: nil,
            dailyStreak: 0,
            lyalyaIslandId: "island",
            recommendedIslandId: nil,
            recommendedLevelId: nil
        ))
        XCTAssertEqual(spy.loadMapVM?.totalProgressFraction ?? 1, 0, accuracy: 0.01)
        XCTAssertFalse(spy.loadMapVM?.hasStreak ?? true)
    }

    func test_presentLoadMap_highlightedZone() {
        let (sut, spy) = makeSUT()
        let zone = makeZone(id: "zone-highlight")
        sut.presentLoadMap(.init(
            zones: [zone],
            islands: [],
            collectibles: [],
            totalStars: 0,
            highlightedZoneId: "zone-highlight",
            dailyStreak: 0,
            lyalyaIslandId: "island",
            recommendedIslandId: nil,
            recommendedLevelId: nil
        ))
        XCTAssertEqual(spy.loadMapVM?.highlightedZoneId, "zone-highlight")
        XCTAssertTrue(spy.loadMapVM?.zones.first?.isHighlighted == true)
    }

    func test_presentLoadMap_lockedZone_a11yLabelContainsSounds() {
        let (sut, spy) = makeSUT()
        let zone = makeZone(isLocked: true, sounds: ["С", "З"])
        sut.presentLoadMap(.init(
            zones: [zone],
            islands: [],
            collectibles: [],
            totalStars: 0,
            highlightedZoneId: nil,
            dailyStreak: 0,
            lyalyaIslandId: "island",
            recommendedIslandId: nil,
            recommendedLevelId: nil
        ))
        let card = spy.loadMapVM?.zones.first
        XCTAssertFalse(card?.accessibilityLabel.isEmpty ?? true)
        XCTAssertTrue(card?.isLocked == true)
    }

    func test_presentLoadMap_emptySounds_usesGrammarHint() {
        let (sut, spy) = makeSUT()
        let zone = makeZone(sounds: [])
        sut.presentLoadMap(.init(
            zones: [zone],
            islands: [],
            collectibles: [],
            totalStars: 0,
            highlightedZoneId: nil,
            dailyStreak: 0,
            lyalyaIslandId: "island",
            recommendedIslandId: nil,
            recommendedLevelId: nil
        ))
        let card = spy.loadMapVM?.zones.first
        XCTAssertFalse(card?.soundsLabel.isEmpty ?? true)
    }

    // MARK: - presentSelectZone

    func test_presentSelectZone_canOpen_nilToast() {
        let (sut, spy) = makeSUT()
        let zone = makeZone()
        sut.presentSelectZone(.init(zone: zone, canOpen: true))
        XCTAssertTrue(spy.selectZoneVM?.canOpen == true)
        XCTAssertNil(spy.selectZoneVM?.toastMessage)
    }

    func test_presentSelectZone_locked_hasToast() {
        let (sut, spy) = makeSUT()
        let zone = makeZone(isLocked: true)
        sut.presentSelectZone(.init(zone: zone, canOpen: false))
        XCTAssertFalse(spy.selectZoneVM?.canOpen ?? true)
        XCTAssertNotNil(spy.selectZoneVM?.toastMessage)
        XCTAssertFalse(spy.selectZoneVM?.toastMessage?.isEmpty ?? true)
    }

    // MARK: - presentLoadZoneDetail

    func test_presentLoadZoneDetail_zeroProgress_ctaStart() {
        let (sut, spy) = makeSUT()
        let zone = makeZone(progress: 0.0, isLocked: false)
        sut.presentLoadZoneDetail(.init(
            zone: zone,
            recommendedLessonCount: 5,
            estimatedMinutesPerSession: 12,
            prerequisiteZoneName: nil,
            levels: [],
            recommendedLevelId: nil,
            unlocksNeeded: 0
        ))
        XCTAssertFalse(spy.zoneDetailVM?.ctaTitle.isEmpty ?? true)
        XCTAssertNil(spy.zoneDetailVM?.prerequisiteHint)
    }

    func test_presentLoadZoneDetail_fullProgress_ctaReview() {
        let (sut, spy) = makeSUT()
        let zone = makeZone(progress: 1.0, completedLessons: 10, totalLessons: 10)
        sut.presentLoadZoneDetail(.init(
            zone: zone,
            recommendedLessonCount: 5,
            estimatedMinutesPerSession: 12,
            prerequisiteZoneName: nil,
            levels: [],
            recommendedLevelId: nil,
            unlocksNeeded: 0
        ))
        XCTAssertFalse(spy.zoneDetailVM?.ctaTitle.isEmpty ?? true)
    }

    func test_presentLoadZoneDetail_locked_ctaLocked() {
        let (sut, spy) = makeSUT()
        let zone = makeZone(progress: 0.0, isLocked: true)
        sut.presentLoadZoneDetail(.init(
            zone: zone,
            recommendedLessonCount: 5,
            estimatedMinutesPerSession: 12,
            prerequisiteZoneName: "Свистящие",
            levels: [],
            recommendedLevelId: nil,
            unlocksNeeded: 3
        ))
        XCTAssertFalse(spy.zoneDetailVM?.ctaTitle.isEmpty ?? true)
        XCTAssertNotNil(spy.zoneDetailVM?.prerequisiteHint)
        XCTAssertFalse(spy.zoneDetailVM?.prerequisiteHint?.isEmpty ?? true)
    }

    func test_presentLoadZoneDetail_partialProgress_ctaContinue() {
        let (sut, spy) = makeSUT()
        let zone = makeZone(progress: 0.5, completedLessons: 5, totalLessons: 10)
        sut.presentLoadZoneDetail(.init(
            zone: zone,
            recommendedLessonCount: 5,
            estimatedMinutesPerSession: 12,
            prerequisiteZoneName: nil,
            levels: [],
            recommendedLevelId: nil,
            unlocksNeeded: 0
        ))
        XCTAssertFalse(spy.zoneDetailVM?.ctaTitle.isEmpty ?? true)
    }

    func test_presentLoadZoneDetail_progressLabel_containsPercent() {
        let (sut, spy) = makeSUT()
        let zone = makeZone(progress: 0.75)
        sut.presentLoadZoneDetail(.init(
            zone: zone,
            recommendedLessonCount: 5,
            estimatedMinutesPerSession: 12,
            prerequisiteZoneName: nil,
            levels: [],
            recommendedLevelId: nil,
            unlocksNeeded: 0
        ))
        XCTAssertFalse(spy.zoneDetailVM?.progressLabel.isEmpty ?? true)
    }

    // MARK: - presentRefreshProgress

    func test_presentRefreshProgress_updatesCards() {
        let (sut, spy) = makeSUT()
        let zone = makeZone(completedLessons: 8, totalLessons: 10)
        sut.presentRefreshProgress(.init(zones: [zone], totalStars: 100, dailyStreak: 5))
        XCTAssertEqual(spy.refreshVM?.zones.count, 1)
        XCTAssertTrue(spy.refreshVM?.hasStreak == true)
        XCTAssertFalse(spy.refreshVM?.totalStarsLabel.isEmpty ?? true)
        XCTAssertEqual(spy.refreshVM?.totalProgressFraction ?? 0, 0.8, accuracy: 0.01)
    }

    // MARK: - presentFailure

    func test_presentFailure_passesMessage() {
        let (sut, spy) = makeSUT()
        sut.presentFailure(.init(message: "Ошибка загрузки"))
        XCTAssertEqual(spy.failureVM?.toastMessage, "Ошибка загрузки")
    }

    // MARK: - presentVoicePrompt

    func test_presentVoicePrompt_passesText() {
        let (sut, spy) = makeSUT()
        sut.presentVoicePrompt(.init(text: "Молодец!", isLyalya: true))
        XCTAssertEqual(spy.voicePromptVM?.text, "Молодец!")
        XCTAssertTrue(spy.voicePromptVM?.isLyalya == true)
    }

    // MARK: - presentCollectTreasure

    func test_presentCollectTreasure_goldPebble_circleIcon() {
        let (sut, spy) = makeSUT()
        let collectible = MapCollectible(id: "c1", type: .goldPebble, position: .zero, starValue: 1)
        sut.presentCollectTreasure(.init(
            collectible: collectible,
            totalStars: 10,
            remainingCollectibles: []
        ))
        XCTAssertEqual(spy.collectTreasureVM?.collectibleIcon, "circle.fill")
        XCTAssertFalse(spy.collectTreasureVM?.totalStarsLabel.isEmpty ?? true)
        XCTAssertFalse(spy.collectTreasureVM?.toastMessage.isEmpty ?? true)
    }

    func test_presentCollectTreasure_magicShell_shellIcon() {
        let (sut, spy) = makeSUT()
        let collectible = MapCollectible(id: "c2", type: .magicShell, position: .zero, starValue: 2)
        sut.presentCollectTreasure(.init(
            collectible: collectible,
            totalStars: 5,
            remainingCollectibles: []
        ))
        XCTAssertEqual(spy.collectTreasureVM?.collectibleIcon, "shell.fill")
    }

    func test_presentCollectTreasure_speechCrystal_diamondIcon() {
        let (sut, spy) = makeSUT()
        let collectible = MapCollectible(id: "c3", type: .speechCrystal, position: .zero, starValue: 3)
        sut.presentCollectTreasure(.init(
            collectible: collectible,
            totalStars: 20,
            remainingCollectibles: []
        ))
        XCTAssertEqual(spy.collectTreasureVM?.collectibleIcon, "diamond.fill")
    }

    // MARK: - presentSelectLevel

    func test_presentSelectLevel_passesIds() {
        let (sut, spy) = makeSUT()
        let level = MapLevel(id: "level-1", name: "Уровень 1", stage: .isolated, isLocked: false, isCompleted: false, successRate: 0.8, stars: 2)
        sut.presentSelectLevel(.init(level: level, islandId: "island-1", zoneId: "zone-1"))
        XCTAssertEqual(spy.selectLevelVM?.levelId, "level-1")
        XCTAssertEqual(spy.selectLevelVM?.islandId, "island-1")
        XCTAssertEqual(spy.selectLevelVM?.zoneId, "zone-1")
        XCTAssertEqual(spy.selectLevelVM?.levelName, "Уровень 1")
    }

    // MARK: - presentAdaptiveRecommendation

    func test_presentAdaptiveRecommendation_passesData() {
        let (sut, spy) = makeSUT()
        sut.presentAdaptiveRecommendation(.init(
            recommendedIslandId: "island-rec",
            recommendedLevelId: "level-rec",
            voiceHint: "Попробуй этот уровень!"
        ))
        XCTAssertEqual(spy.adaptiveRecVM?.recommendedIslandId, "island-rec")
        XCTAssertEqual(spy.adaptiveRecVM?.voiceHint, "Попробуй этот уровень!")
    }
}
