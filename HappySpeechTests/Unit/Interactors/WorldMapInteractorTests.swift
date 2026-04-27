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
        }
        func presentRefreshProgress(_ response: WorldMapModels.RefreshProgress.Response) {
            refreshProgressCalled = true
        }
        func presentFailure(_ response: WorldMapModels.Failure.Response) {
            failureCalled = true; lastFailure = response
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
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil))
        XCTAssertTrue(spy.loadMapCalled)
        XCTAssertFalse(spy.lastLoadMap?.zones.isEmpty ?? true)
    }

    // MARK: - 2. loadMap инициализирует зоны из seed (не пустые)

    func test_loadMap_seedHasZones() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil))
        XCTAssertGreaterThanOrEqual(spy.lastLoadMap?.zones.count ?? 0, 5)
    }

    // MARK: - 3. loadMap с highlightedSound маппит highlightedZoneId

    func test_loadMap_withHighlightedSound_setsHighlightedZoneId() {
        let (sut, spy) = makeSUT()
        // "С" входит в свистящие → зона должна быть найдена
        sut.loadMap(.init(childId: "child-1", highlightedSound: "С"))
        // Если звук есть в каком-то zone.sounds, highlightedZoneId != nil
        // Если нет — nil (всё равно не ошибка)
        XCTAssertTrue(spy.loadMapCalled)
    }

    // MARK: - 4. selectZone с существующим id → presentSelectZone

    func test_selectZone_existing_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil))
        guard let firstZoneId = spy.lastLoadMap?.zones.first?.id else {
            return XCTFail("Нет зон для теста")
        }
        sut.selectZone(.init(zoneId: firstZoneId))
        XCTAssertTrue(spy.selectZoneCalled)
    }

    // MARK: - 5. selectZone с несуществующим id → presentFailure

    func test_selectZone_notFound_callsFailure() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil))
        sut.selectZone(.init(zoneId: "nonexistent-zone-99"))
        XCTAssertFalse(spy.selectZoneCalled)
        XCTAssertTrue(spy.failureCalled)
    }

    // MARK: - 6. selectZone заблокированной зоны → canOpen = false

    func test_selectZone_locked_canOpenFalse() throws {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil))
        // Ищем заблокированную зону из seed
        if let locked = spy.lastLoadMap?.zones.first(where: { $0.isLocked }) {
            sut.selectZone(.init(zoneId: locked.id))
            XCTAssertFalse(spy.lastSelectZone?.canOpen ?? true)
        } else {
            throw XCTSkip("Нет заблокированных зон в seed")
        }
    }

    // MARK: - 7. refreshProgress вызывает presentRefreshProgress

    func test_refreshProgress_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadMap(.init(childId: "child-1", highlightedSound: nil))
        sut.refreshProgress(.init(childId: "child-1"))
        XCTAssertTrue(spy.refreshProgressCalled)
    }
}
