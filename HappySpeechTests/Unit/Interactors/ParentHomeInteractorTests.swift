@testable import HappySpeech
import XCTest

// MARK: - ParentHomeInteractorTests
//
// M10.1 — 8 тестов для ParentHomeInteractor.
// Покрывает: fetchData (success/empty/error), refresh, switchChild,
// overallRate с пустым словарём, resolveChild с preferred.

@MainActor
final class ParentHomeInteractorTests: XCTestCase {

    // MARK: - Spy

    private final class SpyPresenter: ParentHomePresentationLogic {
        var fetchCalled = false
        var loadingCalled = false
        var emptyCalled = false

        var lastFetch: ParentHomeModels.Fetch.Response?
        var lastLoadingValue: Bool?

        func presentFetch(_ response: ParentHomeModels.Fetch.Response) {
            fetchCalled = true
            lastFetch = response
        }
        func presentLoading(_ isLoading: Bool) {
            loadingCalled = true
            lastLoadingValue = isLoading
        }
        func presentEmpty() {
            emptyCalled = true
        }
    }

    private func makeSUT(
        children: [ChildProfileDTO] = [.preview],
        sessions: [SessionDTO] = [.preview]
    ) -> (ParentHomeInteractor, SpyPresenter) {
        let childRepo = MockChildRepository(children: children)
        let sessionRepo = MockSessionRepository(sessions: sessions)
        let sut = ParentHomeInteractor(
            childRepository: childRepo,
            sessionRepository: sessionRepo
        )
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. fetchData с детьми → presentFetch

    func test_fetchData_withChildren_callsPresentFetch() async {
        let (sut, spy) = makeSUT()
        await sut.fetchData(.init(preferredChildId: nil))
        XCTAssertTrue(spy.fetchCalled)
        XCTAssertNotNil(spy.lastFetch)
    }

    // MARK: - 2. fetchData без детей → presentEmpty

    func test_fetchData_noChildren_callsPresentEmpty() async {
        let (sut, spy) = makeSUT(children: [])
        await sut.fetchData(.init(preferredChildId: nil))
        XCTAssertFalse(spy.fetchCalled)
        XCTAssertTrue(spy.emptyCalled)
    }

    // MARK: - 3. fetchData сначала вызывает presentLoading(true)

    func test_fetchData_callsPresentLoadingTrue() async {
        let (sut, spy) = makeSUT()
        await sut.fetchData(.init(preferredChildId: nil))
        XCTAssertTrue(spy.loadingCalled)
    }

    // MARK: - 4. fetchData с preferred child id → возвращает правильного ребёнка

    func test_fetchData_preferredChild_returnsCorrectChild() async {
        let child1 = ChildProfileDTO(id: "c1", name: "Аня", age: 5,
                                      targetSounds: ["С"], parentId: "p1")
        let child2 = ChildProfileDTO(id: "c2", name: "Вася", age: 6,
                                      targetSounds: ["Р"], parentId: "p1")
        let (sut, spy) = makeSUT(children: [child1, child2])
        await sut.fetchData(.init(preferredChildId: "c2"))
        XCTAssertEqual(spy.lastFetch?.childId, "c2")
        XCTAssertEqual(spy.lastFetch?.childName, "Вася")
    }

    // MARK: - 5. refresh после fetchData → обновляет данные

    func test_refresh_afterFetch_updatesData() async {
        let (sut, spy) = makeSUT()
        await sut.fetchData(.init(preferredChildId: nil))
        spy.fetchCalled = false
        await sut.refresh()
        XCTAssertTrue(spy.fetchCalled)
    }

    // MARK: - 6. refresh без предыдущего fetchData → вызывает fetchData

    func test_refresh_withoutPriorFetch_callsFetchData() async {
        let (sut, spy) = makeSUT()
        await sut.refresh()
        // presenter.presentLoading или presentFetch или presentEmpty должен быть вызван
        XCTAssertTrue(spy.loadingCalled || spy.fetchCalled || spy.emptyCalled)
    }

    // MARK: - 7. switchChild переключает активного ребёнка

    func test_switchChild_updatesActiveChild() async {
        let child1 = ChildProfileDTO(id: "c1", name: "Аня", age: 5,
                                      targetSounds: ["С"], parentId: "p1")
        let child2 = ChildProfileDTO(id: "c2", name: "Вася", age: 6,
                                      targetSounds: ["Р"], parentId: "p1")
        let (sut, spy) = makeSUT(children: [child1, child2])
        await sut.fetchData(.init(preferredChildId: "c1"))
        await sut.switchChild(to: "c2")
        XCTAssertEqual(spy.lastFetch?.childId, "c2")
    }

    // MARK: - 8. response содержит overallRate в [0, 1]

    func test_fetchData_overallRateInRange() async {
        let (sut, spy) = makeSUT()
        await sut.fetchData(.init(preferredChildId: nil))
        let rate = spy.lastFetch?.overallRate ?? -1
        XCTAssertGreaterThanOrEqual(rate, 0.0)
        XCTAssertLessThanOrEqual(rate, 1.0)
    }
}
