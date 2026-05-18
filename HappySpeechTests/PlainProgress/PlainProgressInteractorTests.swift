@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubPlainProgressWorker: PlainProgressWorkerProtocol {
    var response: PlainProgressModels.Load.Response
    var error: Error?
    private(set) var loadCallCount = 0

    init(response: PlainProgressModels.Load.Response) {
        self.response = response
    }

    func loadProgress(childId: String) async throws -> PlainProgressModels.Load.Response {
        loadCallCount += 1
        if let error { throw error }
        return response
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyPlainProgressPresenter: PlainProgressPresentationLogic, @unchecked Sendable {
    var loadCount = 0
    var failureCount = 0
    var shareCount = 0
    var lastResponse: PlainProgressModels.Load.Response?
    var lastShareResponse: PlainProgressModels.Load.Response?

    func presentLoad(response: PlainProgressModels.Load.Response) async {
        loadCount += 1
        lastResponse = response
    }
    func presentLoadFailure(error: Error) async {
        failureCount += 1
    }
    func presentShare(response: PlainProgressModels.Load.Response) async {
        shareCount += 1
        lastShareResponse = response
    }
}

// MARK: - Helpers

@MainActor
private func makeResponse(
    weekRate: Double = 0.8,
    prevRate: Double = 0.7,
    monthRate: Double = 0.5,
    sessions: Int = 5,
    hasData: Bool = true,
    trend: PlainProgressDirection = .improved
) -> PlainProgressModels.Load.Response {
    .init(
        childName: "Миша",
        childAge: 6,
        weekSuccessRate: weekRate,
        previousWeekSuccessRate: prevRate,
        monthAgoSuccessRate: monthRate,
        sessionsThisWeek: sessions,
        practiceMinutesThisWeek: 40,
        focusSound: "Р",
        focusSoundRate: weekRate,
        targetSounds: ["Р"],
        currentStreak: 3,
        trend: trend,
        hasWeekData: hasData
    )
}

// MARK: - Interactor Tests

@MainActor
final class PlainProgressInteractorTests: XCTestCase {

    private func makeSUT(
        response: PlainProgressModels.Load.Response
    ) -> (PlainProgressInteractor, SpyPlainProgressPresenter, StubPlainProgressWorker, SpyHapticService) {
        let worker = StubPlainProgressWorker(response: response)
        let haptic = SpyHapticService()
        let sut = PlainProgressInteractor(childId: "child-1", worker: worker, hapticService: haptic)
        let spy = SpyPlainProgressPresenter()
        sut.presenter = spy
        return (sut, spy, worker, haptic)
    }

    func test_load_callsWorkerAndPresentsResponse() async {
        let (sut, spy, worker, _) = makeSUT(response: makeResponse())
        await sut.load(request: .init(childId: "child-1"))
        XCTAssertEqual(worker.loadCallCount, 1)
        XCTAssertEqual(spy.loadCount, 1)
        XCTAssertEqual(spy.lastResponse?.childName, "Миша")
    }

    func test_load_storesResponseInDataStore() async {
        let (sut, _, _, _) = makeSUT(response: makeResponse())
        await sut.load(request: .init(childId: "child-1"))
        XCTAssertNotNil(sut.lastResponse)
        XCTAssertEqual(sut.childId, "child-1")
    }

    func test_load_failurePropagatesToPresenter() async {
        let (sut, spy, worker, _) = makeSUT(response: makeResponse())
        worker.error = NSError(domain: "test", code: 1)
        await sut.load(request: .init(childId: "child-1"))
        XCTAssertEqual(spy.failureCount, 1)
        XCTAssertEqual(spy.loadCount, 0)
    }

    func test_share_beforeLoad_doesNothing() async {
        let (sut, spy, _, _) = makeSUT(response: makeResponse())
        await sut.share(request: .init())
        XCTAssertEqual(spy.shareCount, 0)
    }

    func test_share_afterLoad_presentsSummary() async {
        let (sut, spy, _, haptic) = makeSUT(response: makeResponse())
        await sut.load(request: .init(childId: "child-1"))
        await sut.share(request: .init())
        XCTAssertEqual(spy.shareCount, 1)
        XCTAssertEqual(haptic.selectionCount, 1)
        XCTAssertEqual(spy.lastShareResponse?.childName, "Миша")
    }
}
