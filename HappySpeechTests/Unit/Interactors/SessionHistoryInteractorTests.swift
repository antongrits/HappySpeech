@testable import HappySpeech
import XCTest

// MARK: - SessionHistoryInteractorTests
//
// M10.1 — 6 тестов для SessionHistoryInteractor.
// Покрывает: loadHistory, forceReload, applyFilter,
// clearFilter, openSession (happy/not found).

@MainActor
final class SessionHistoryInteractorTests: XCTestCase {

    // MARK: - Spy

    @MainActor
    private final class SpyPresenter: SessionHistoryPresentationLogic {
        var loadHistoryCalled = false
        var applyFilterCalled = false
        var clearFilterCalled = false
        var openSessionCalled = false
        var failureCalled = false

        var lastLoadHistoryResponse: SessionHistoryModels.LoadHistory.Response?
        var lastOpenSessionResponse: SessionHistoryModels.OpenSession.Response?

        func presentLoadHistory(_ response: SessionHistoryModels.LoadHistory.Response) {
            loadHistoryCalled = true
            lastLoadHistoryResponse = response
        }
        func presentApplyFilter(_ response: SessionHistoryModels.ApplyFilter.Response) {
            applyFilterCalled = true
        }
        func presentClearFilter(_ response: SessionHistoryModels.ClearFilter.Response) {
            clearFilterCalled = true
        }
        func presentOpenSession(_ response: SessionHistoryModels.OpenSession.Response) {
            openSessionCalled = true
            lastOpenSessionResponse = response
        }
        func presentFailure(_ response: SessionHistoryModels.Failure.Response) {
            failureCalled = true
        }
    }

    private func makeSUT() -> (SessionHistoryInteractor, SpyPresenter) {
        let sut = SessionHistoryInteractor()
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. loadHistory заполняет сессии из seed

    func test_loadHistory_populatesSessions() {
        let (sut, spy) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        XCTAssertTrue(spy.loadHistoryCalled)
        XCTAssertFalse(spy.lastLoadHistoryResponse?.allSessions.isEmpty ?? true)
    }

    // MARK: - 2. loadHistory с forceReload пересоздаёт данные

    func test_loadHistory_forceReload_resetsData() {
        let (sut, spy) = makeSUT()
        sut.loadHistory(.init(forceReload: true))
        XCTAssertTrue(spy.loadHistoryCalled)
        let count = spy.lastLoadHistoryResponse?.allSessions.count ?? 0
        XCTAssertGreaterThan(count, 0)
    }

    // MARK: - 3. applyFilter вызывает presentApplyFilter

    func test_applyFilter_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        let filter = SessionFilter(fromDate: nil, toDate: nil, sounds: ["Р"])
        sut.applyFilter(.init(filter: filter))
        XCTAssertTrue(spy.applyFilterCalled)
    }

    // MARK: - 4. clearFilter вызывает presentClearFilter

    func test_clearFilter_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        let filter = SessionFilter(fromDate: nil, toDate: nil, sounds: ["Р"])
        sut.applyFilter(.init(filter: filter))
        sut.clearFilter(.init())
        XCTAssertTrue(spy.clearFilterCalled)
    }

    // MARK: - 5. openSession с существующим ID → presentOpenSession

    func test_openSession_existingId_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        guard let firstId = spy.lastLoadHistoryResponse?.allSessions.first?.id else {
            return XCTFail("Нет сессий в seed")
        }
        sut.openSession(.init(id: firstId))
        XCTAssertTrue(spy.openSessionCalled)
        XCTAssertEqual(spy.lastOpenSessionResponse?.session.id, firstId)
    }

    // MARK: - 6. openSession с несуществующим ID → presentFailure

    func test_openSession_notFound_callsFailure() {
        let (sut, spy) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        sut.openSession(.init(id: "nonexistent-session-99"))
        XCTAssertFalse(spy.openSessionCalled)
        XCTAssertTrue(spy.failureCalled)
    }
}
