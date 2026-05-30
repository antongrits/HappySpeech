@testable import HappySpeech
import XCTest

// MARK: - ParentDailyDigestInteractorTests
//
// ParentDailyDigestInteractor is a thin VIP MVP variant (@Observable). It exposes
// a static daily digest (KPIs, a photo-moment and a tip); refresh() is currently a
// no-op stub. Tests pin the seed state and assert refresh() leaves it untouched.

@MainActor
final class ParentDailyDigestInteractorTests: XCTestCase {

    private func makeSUT() -> ParentDailyDigestInteractor {
        ParentDailyDigestInteractor()
    }

    // MARK: - Initial state

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_hasKPIs() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.kpis.isEmpty)
        XCTAssertEqual(Set(sut.state.kpis.map(\.id)).count, sut.state.kpis.count)
        for kpi in sut.state.kpis {
            XCTAssertFalse(kpi.icon.isEmpty)
            XCTAssertFalse(kpi.value.isEmpty)
            XCTAssertFalse(kpi.label.isEmpty)
        }
    }

    func test_initialState_photoMomentPopulated() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.photoMomentEmoji.isEmpty)
        XCTAssertFalse(sut.state.photoMomentCaption.isEmpty)
    }

    func test_initialState_tipPopulated() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.tip.text.isEmpty)
        XCTAssertFalse(sut.state.tip.author.isEmpty)
    }

    // MARK: - refresh (stub)

    func test_refresh_leavesStateUnchanged() {
        let sut = makeSUT()
        let before = sut.state
        sut.refresh()
        XCTAssertEqual(sut.state, before)
    }
}
