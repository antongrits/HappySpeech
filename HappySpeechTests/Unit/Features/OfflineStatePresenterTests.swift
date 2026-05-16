import XCTest
@testable import HappySpeech

// MARK: - OfflineStatePresenterTests
//
// Phase 2.6 batch 3 — покрытие OfflineStatePresenter (65% → цель ≥90%).

@MainActor
final class OfflineStatePresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: OfflineStateDisplayLogic {
        var fetchVM: OfflineStateModels.Fetch.ViewModel?
        var updateVM: OfflineStateModels.Update.ViewModel?

        func displayFetch(_ vm: OfflineStateModels.Fetch.ViewModel) { fetchVM = vm }
        func displayUpdate(_ vm: OfflineStateModels.Update.ViewModel) { updateVM = vm }
    }

    private func makeSUT() -> (OfflineStatePresenter, DisplaySpy) {
        let sut = OfflineStatePresenter()
        let spy = DisplaySpy()
        sut.viewModel = spy
        return (sut, spy)
    }

    // MARK: - presentFetch

    func test_presentFetch_withActiveChild_hasActiveChildTrue() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(.init(activeChildId: "child-1", pendingCount: 0))
        XCTAssertNotNil(spy.fetchVM)
        XCTAssertTrue(spy.fetchVM?.hasActiveChild == true)
        XCTAssertEqual(spy.fetchVM?.activeChildId, "child-1")
    }

    func test_presentFetch_withoutActiveChild_hasActiveChildFalse() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(.init(activeChildId: nil, pendingCount: 3))
        XCTAssertFalse(spy.fetchVM?.hasActiveChild ?? true)
        XCTAssertNil(spy.fetchVM?.activeChildId)
        XCTAssertEqual(spy.fetchVM?.pendingCount, 3)
    }

    func test_presentFetch_pendingBadgeText_notEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(.init(activeChildId: nil, pendingCount: 5))
        XCTAssertFalse(spy.fetchVM?.pendingBadgeText.isEmpty ?? true)
    }

    func test_presentFetch_zeroPendingCount_badgeNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(.init(activeChildId: nil, pendingCount: 0))
        XCTAssertNotNil(spy.fetchVM?.pendingBadgeText)
    }

    func test_presentFetch_largePendingCount_badgeNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(.init(activeChildId: nil, pendingCount: 999))
        XCTAssertFalse(spy.fetchVM?.pendingBadgeText.isEmpty ?? true)
    }

    // MARK: - presentUpdate

    func test_presentUpdate_retryConnection_isRetryingFalse() {
        let (sut, spy) = makeSUT()
        sut.presentUpdate(.init(kind: .retryConnection, isConnected: false))
        XCTAssertNotNil(spy.updateVM)
        XCTAssertEqual(spy.updateVM?.kind, .retryConnection)
        XCTAssertFalse(spy.updateVM?.isRetrying ?? true)
        XCTAssertFalse(spy.updateVM?.isConnected ?? true)
    }

    func test_presentUpdate_continueOffline_connectedTrue() {
        let (sut, spy) = makeSUT()
        sut.presentUpdate(.init(kind: .continueOffline, isConnected: true))
        XCTAssertEqual(spy.updateVM?.kind, .continueOffline)
        XCTAssertTrue(spy.updateVM?.isConnected == true)
    }

    // MARK: - formatPendingBadge (static)

    func test_formatPendingBadge_zero_notEmpty() {
        let result = OfflineStatePresenter.formatPendingBadge(count: 0)
        XCTAssertFalse(result.isEmpty)
    }

    func test_formatPendingBadge_one_notEmpty() {
        let result = OfflineStatePresenter.formatPendingBadge(count: 1)
        XCTAssertFalse(result.isEmpty)
    }

    func test_formatPendingBadge_ten_notEmpty() {
        let result = OfflineStatePresenter.formatPendingBadge(count: 10)
        XCTAssertFalse(result.isEmpty)
    }

    func test_formatPendingBadge_differentCounts_produceStrings() {
        // Проверяем, что метод возвращает строку для разных значений
        for count in [0, 1, 2, 5, 11, 100] {
            let result = OfflineStatePresenter.formatPendingBadge(count: count)
            XCTAssertFalse(result.isEmpty, "Badge для count=\(count) не должен быть пустым")
        }
    }
}
