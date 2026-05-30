@testable import HappySpeech
import XCTest

// MARK: - WeeklyParentTipInteractorTests
//
// WeeklyParentTipInteractor is a thin VIP MVP variant (@Observable). It surfaces a
// single weekly tip; recordShare() is currently a logging-only stub. Tests pin the
// seed tip and assert recordShare() leaves the state untouched.

@MainActor
final class WeeklyParentTipInteractorTests: XCTestCase {

    private func makeSUT() -> WeeklyParentTipInteractor {
        WeeklyParentTipInteractor()
    }

    // MARK: - Initial state

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_tipPopulated() {
        let sut = makeSUT()
        let tip = sut.state.tip
        XCTAssertFalse(tip.id.isEmpty)
        XCTAssertFalse(tip.weekLabel.isEmpty)
        XCTAssertFalse(tip.title.isEmpty)
        XCTAssertFalse(tip.authorName.isEmpty)
        XCTAssertFalse(tip.authorRole.isEmpty)
    }

    func test_initialState_tipHasBodyAndBullets() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.tip.bodyParagraphs.isEmpty)
        XCTAssertFalse(sut.state.tip.bulletPoints.isEmpty)
        XCTAssertTrue(sut.state.tip.bodyParagraphs.allSatisfy { !$0.isEmpty })
        XCTAssertTrue(sut.state.tip.bulletPoints.allSatisfy { !$0.isEmpty })
    }

    // MARK: - recordShare (stub)

    func test_recordShare_leavesStateUnchanged() {
        let sut = makeSUT()
        let before = sut.state
        sut.recordShare()
        XCTAssertEqual(sut.state, before)
    }
}
