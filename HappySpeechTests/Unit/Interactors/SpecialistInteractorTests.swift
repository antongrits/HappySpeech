@testable import HappySpeech
import XCTest

// MARK: - SpecialistInteractorTests
//
// M10.1 — 5 тестов для SpecialistInteractor.
// Покрывает: fetch, update, openSessionReview (empty/valid id),
// начальное состояние presenter.

@MainActor
final class SpecialistInteractorTests: XCTestCase {

    // MARK: - Spy

    @MainActor
    private final class SpyPresenter: SpecialistPresentationLogic {
        var fetchCalled = false
        var updateCalled = false

        func presentFetch(_ response: SpecialistModels.Fetch.Response) {
            fetchCalled = true
        }
        func presentUpdate(_ response: SpecialistModels.Update.Response) {
            updateCalled = true
        }
    }

    // MARK: - Helpers

    private func makeSUT() -> (SpecialistInteractor, SpyPresenter) {
        let sut = SpecialistInteractor()
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    private func makeSUTWithRouter() -> (SpecialistInteractor, SpyPresenter, SpecialistRouter) {
        let sut = SpecialistInteractor()
        let spy = SpyPresenter()
        let router = SpecialistRouter()
        var routedId: String?
        router.onOpenSessionReview = { id in routedId = id }
        sut.presenter = spy
        sut.router = router
        return (sut, spy, router)
    }

    // MARK: - 1. fetch вызывает presentFetch

    func test_fetch_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.fetch(.init())
        XCTAssertTrue(spy.fetchCalled)
    }

    // MARK: - 2. update вызывает presentUpdate

    func test_update_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.update(.init())
        XCTAssertTrue(spy.updateCalled)
    }

    // MARK: - 3. openSessionReview с пустым id пропускает роутер

    func test_openSessionReview_emptyId_doesNotCallRouter() {
        let (sut, _, router) = makeSUTWithRouter()
        var routedId: String?
        router.onOpenSessionReview = { id in routedId = id }
        sut.openSessionReview(sessionId: "")
        XCTAssertNil(routedId)
    }

    // MARK: - 4. openSessionReview с корректным id → колбэк роутера вызывается

    func test_openSessionReview_validId_callsRouterCallback() {
        let (sut, _, router) = makeSUTWithRouter()
        var routedId: String?
        router.onOpenSessionReview = { id in routedId = id }
        sut.openSessionReview(sessionId: "session-42")
        XCTAssertEqual(routedId, "session-42")
    }

    // MARK: - 5. presenter по умолчанию nil, что не крашит fetch

    func test_init_presenterNil_fetchDoesNotCrash() {
        let sut = SpecialistInteractor()
        // presenter не установлен — должен вызываться без краша
        XCTAssertNoThrow(sut.fetch(.init()))
    }
}
