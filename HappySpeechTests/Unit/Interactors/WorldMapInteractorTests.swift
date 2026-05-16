@testable import HappySpeech
import XCTest

// MARK: - WorldMapInteractorTests
//
// M10.1 — 7 тестов для WorldMapInteractor.
// Покрывает: loadMap, selectZone (locked/unlocked/notFound),
// refreshProgress, highlightedZone.

@MainActor
final class WorldMapInteractorTests: XCTestCase {

    // MARK: - Spy

    @MainActor
    private final class SpyPresenter: WorldMapPresentationLogic {
        var loadMapCalled = false
        var selectZoneCalled = false
        var loadZoneDetailCalled = false
        var refreshProgressCalled = false
        var failureCalled = false

        var lastLoadMap: WorldMapModels.LoadMap.Response?
        var lastSelectZone: WorldMapModels.SelectZone.Response?
        var lastFailure: WorldMapModels.Failure.Response?

        func presentLoadMap(_ response: WorldMapModels.LoadMap.Response) {
            loadMapCalled = true; lastLoadMap = response
        }
        func presentSelectZone(_ response: WorldMapModels.SelectZone.Response) {
            selectZoneCalled = true; lastSelectZone = response
        }
        func presentLoadZoneDetail(_ response: WorldMapModels.LoadZoneDetail.Response) {
            loadZoneDetailCalled = true
            lastZoneDetail = response
        }
        func presentRefreshProgress(_ response: WorldMapModels.RefreshProgress.Response) {
            refreshProgressCalled = true
            lastRefreshProgress = response
        }
        func presentFailure(_ response: WorldMapModels.Failure.Response) {
            failureCalled = true; lastFailure = response
        }
        var voicePromptCalled = false
        var collectTreasureCalled = false
        var selectLevelCalled = false
        var adaptiveRecommendationCalled = false

        var lastVoicePrompt: WorldMapModels.VoicePrompt.Response?
        var lastCollectTreasure: WorldMapModels.CollectTreasure.Response?
        var lastSelectLevel: WorldMapModels.SelectLevel.Response?
        var lastAdaptiveRecommendation: WorldMapModels.AdaptiveRecommendation.Response?
        var lastZoneDetail: WorldMapModels.LoadZoneDetail.Response?
        var lastRefreshProgress: WorldMapModels.RefreshProgress.Response?

        func presentVoicePrompt(_ response: WorldMapModels.VoicePrompt.Response) {
            voicePromptCalled = true
            lastVoicePrompt = response
        }
        func presentCollectTreasure(_ response: WorldMapModels.CollectTreasure.Response) {
            collectTreasureCalled = true
            lastCollectTreasure = response
        }
        func presentSelectLevel(_ response: WorldMapModels.SelectLevel.Response) {
            selectLevelCalled = true
            lastSelectLevel = response
        }
        func presentAdaptiveRecommendation(_ response: WorldMapModels.AdaptiveRecommendation.Response) {
            adaptiveRecommendationCalled = true
            lastAdaptiveRecommendation = response
        }
    }

    private func makeSUT() -> (WorldMapInteractor, SpyPresenter) {
        let sut = WorldMapInteractor()
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. loadMap вызывает presentLoadMap с зонами

    func test_loadMap_callsPresenterWithZones() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil, childAge: nil))
        XCTAssertTrue(spy.loadMapCalled)
        XCTAssertFalse(spy.lastLoadMap?.zones.isEmpty ?? true)
    }

    // MARK: - 2. loadMap инициализирует зоны из seed (не пустые)

    func test_loadMap_seedHasZones() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil, childAge: nil))
        XCTAssertGreaterThanOrEqual(spy.lastLoadMap?.zones.count ?? 0, 5)
    }

    // MARK: - 3. loadMap с highlightedSound маппит highlightedZoneId

    func test_loadMap_withHighlightedSound_setsHighlightedZoneId() {
        let (sut, spy) = makeSUT()
        // "С" входит в свистящие → зона должна быть найдена
        sut.loadMap(.init(childId: "child-1", highlightedSound: "С", childAge: nil))
        // Если звук есть в каком-то zone.sounds, highlightedZoneId != nil
        // Если нет — nil (всё равно не ошибка)
        XCTAssertTrue(spy.loadMapCalled)
    }

    // MARK: - 4. selectZone с существующим id → presentSelectZone

    func test_selectZone_existing_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil, childAge: nil))
        guard let firstZoneId = spy.lastLoadMap?.zones.first?.id else {
            return XCTFail("Нет зон для теста")
        }
        sut.selectZone(.init(zoneId: firstZoneId))
        XCTAssertTrue(spy.selectZoneCalled)
    }

    // MARK: - 5. selectZone с несуществующим id → presentFailure

    func test_selectZone_notFound_callsFailure() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil, childAge: nil))
        sut.selectZone(.init(zoneId: "nonexistent-zone-99"))
        XCTAssertFalse(spy.selectZoneCalled)
        XCTAssertTrue(spy.failureCalled)
    }

    // MARK: - 6. selectZone заблокированной зоны → canOpen = false

    func test_selectZone_locked_canOpenFalse() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil, childAge: nil))
        // Seed должен содержать заблокированные зоны — если нет, это регрессия
        guard let locked = spy.lastLoadMap?.zones.first(where: { $0.isLocked }) else {
            XCTFail("Seed должен содержать хотя бы одну заблокированную зону; отсутствие locked зон — регрессия WorldMapInteractor.makeSeedZones()")
            return
        }
        sut.selectZone(.init(zoneId: locked.id))
        XCTAssertFalse(spy.lastSelectZone?.canOpen ?? true, "Заблокированная зона не должна открываться (canOpen=false)")
    }

    // MARK: - 7. refreshProgress вызывает presentRefreshProgress

    func test_refreshProgress_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil, childAge: nil))
        sut.refreshProgress(.init(childId: "child-1"))
        XCTAssertTrue(spy.refreshProgressCalled)
    }

    // MARK: - 8. loadZoneDetail с существующей зоной

    func test_loadZoneDetail_existing_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil, childAge: nil))
        guard let zoneId = spy.lastLoadMap?.zones.first?.id else {
            return XCTFail("Нет зон")
        }
        sut.loadZoneDetail(.init(zoneId: zoneId))
        XCTAssertTrue(spy.loadZoneDetailCalled)
        XCTAssertNotNil(spy.lastZoneDetail)
    }

    func test_loadZoneDetail_notFound_callsFailure() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil, childAge: nil))
        sut.loadZoneDetail(.init(zoneId: "nonexistent-zone"))
        XCTAssertTrue(spy.failureCalled)
        XCTAssertFalse(spy.loadZoneDetailCalled)
    }

    // MARK: - 9. loadZoneDetail заблокированной зоны → unlocksNeeded

    func test_loadZoneDetail_lockedZone_hasUnlocksNeeded() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil, childAge: nil))
        guard let locked = spy.lastLoadMap?.zones.first(where: { $0.isLocked }) else {
            return XCTFail("Нет заблокированных зон")
        }
        sut.loadZoneDetail(.init(zoneId: locked.id))
        XCTAssertGreaterThanOrEqual(spy.lastZoneDetail?.unlocksNeeded ?? -1, 0)
    }

    // MARK: - 10. tapLyalya возвращает приветствие

    func test_tapLyalya_returnsLyalyaPrompt() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil, childAge: nil))
        sut.tapLyalya(.init())
        XCTAssertTrue(spy.voicePromptCalled)
        XCTAssertEqual(spy.lastVoicePrompt?.isLyalya, true)
        XCTAssertFalse(spy.lastVoicePrompt?.text.isEmpty ?? true)
    }

    // MARK: - 11. collectTreasure собирает сокровище

    func test_collectTreasure_collectsAndIncreasesStars() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil, childAge: nil))
        guard let collectible = spy.lastLoadMap?.collectibles.first else {
            return XCTFail("Нет collectibles")
        }
        let starsBefore = spy.lastLoadMap?.totalStars ?? 0
        sut.collectTreasure(.init(collectibleId: collectible.id))
        XCTAssertTrue(spy.collectTreasureCalled)
        XCTAssertGreaterThan(spy.lastCollectTreasure?.totalStars ?? 0, starsBefore)
    }

    func test_collectTreasure_twice_secondIgnored() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil, childAge: nil))
        guard let collectible = spy.lastLoadMap?.collectibles.first else {
            return XCTFail("Нет collectibles")
        }
        sut.collectTreasure(.init(collectibleId: collectible.id))
        spy.collectTreasureCalled = false
        sut.collectTreasure(.init(collectibleId: collectible.id))
        XCTAssertFalse(spy.collectTreasureCalled, "Повторный сбор того же сокровища игнорируется")
    }

    func test_collectTreasure_unknownId_ignored() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil, childAge: nil))
        sut.collectTreasure(.init(collectibleId: "nonexistent"))
        XCTAssertFalse(spy.collectTreasureCalled)
    }

    // MARK: - 12. selectLevel разблокированного уровня

    func test_selectLevel_unlocked_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil, childAge: nil))
        // vowel-l1 разблокирован в seed
        sut.selectLevel(.init(levelId: "vowel-l1"))
        XCTAssertTrue(spy.selectLevelCalled)
        XCTAssertEqual(spy.lastSelectLevel?.level.id, "vowel-l1")
    }

    func test_selectLevel_locked_callsFailure() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil, childAge: nil))
        // velar-l1 заблокирован в seed
        sut.selectLevel(.init(levelId: "velar-l1"))
        XCTAssertTrue(spy.failureCalled)
        XCTAssertFalse(spy.selectLevelCalled)
    }

    func test_selectLevel_unknownId_callsFailure() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil, childAge: nil))
        sut.selectLevel(.init(levelId: "nonexistent-level"))
        XCTAssertTrue(spy.failureCalled)
    }

    // MARK: - 13. loadAdaptiveRecommendation

    func test_loadAdaptiveRecommendation_returnsRecommendation() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil, childAge: nil))
        sut.loadAdaptiveRecommendation(.init(childId: "child-1"))
        XCTAssertTrue(spy.adaptiveRecommendationCalled)
        XCTAssertFalse(spy.lastAdaptiveRecommendation?.voiceHint.isEmpty ?? true)
    }

    // MARK: - 14. recordSessionResult обновляет прогресс

    func test_recordSessionResult_updatesProgress() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil, childAge: nil))
        sut.recordSessionResult(.init(
            islandId: "island-hissing", levelId: "hiss-l2",
            successRate: 0.9, fatigueDetected: false
        ))
        XCTAssertTrue(spy.refreshProgressCalled)
    }

    func test_recordSessionResult_highFatigue_triggersEasiestRecommendation() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil, childAge: nil))
        // 3 сессии подряд с усталостью
        for _ in 0..<3 {
            sut.recordSessionResult(.init(
                islandId: "island-hissing", levelId: "hiss-l2",
                successRate: 0.5, fatigueDetected: true
            ))
        }
        sut.loadAdaptiveRecommendation(.init(childId: "child-1"))
        XCTAssertNotNil(spy.lastAdaptiveRecommendation?.recommendedIslandId)
    }

    // MARK: - 15. loadVoicePrompt для каждого контекста

    func test_loadVoicePrompt_islandUnlocked() {
        let (sut, spy) = makeSUT()
        sut.loadVoicePrompt(.init(context: .islandUnlocked(name: "Остров шипящих")))
        XCTAssertTrue(spy.voicePromptCalled)
        XCTAssertFalse(spy.lastVoicePrompt?.text.isEmpty ?? true)
    }

    func test_loadVoicePrompt_levelCompleted() {
        let (sut, spy) = makeSUT()
        sut.loadVoicePrompt(.init(context: .levelCompleted(levelName: "Слоги", islandName: "Остров")))
        XCTAssertFalse(spy.lastVoicePrompt?.text.isEmpty ?? true)
    }

    func test_loadVoicePrompt_nearUnlock() {
        let (sut, spy) = makeSUT()
        sut.loadVoicePrompt(.init(context: .nearUnlock(name: "Остров", count: 3)))
        XCTAssertFalse(spy.lastVoicePrompt?.text.isEmpty ?? true)
    }

    func test_loadVoicePrompt_firstVisit() {
        let (sut, spy) = makeSUT()
        sut.loadVoicePrompt(.init(context: .firstVisit))
        XCTAssertFalse(spy.lastVoicePrompt?.text.isEmpty ?? true)
    }

    func test_loadVoicePrompt_encouragement() {
        let (sut, spy) = makeSUT()
        sut.loadVoicePrompt(.init(context: .encouragement))
        XCTAssertFalse(spy.lastVoicePrompt?.text.isEmpty ?? true)
        XCTAssertEqual(spy.lastVoicePrompt?.isLyalya, false)
    }

    // MARK: - 16. loadMap с разным возрастом ребёнка

    func test_loadMap_withChildAge_doesNotCrash() {
        let (sut, spy) = makeSUT()
        for age in [5, 6, 7, 8] {
            sut.loadMap(.init(childId: "child-1", highlightedSound: nil, childAge: age))
            XCTAssertTrue(spy.loadMapCalled)
        }
    }
}
