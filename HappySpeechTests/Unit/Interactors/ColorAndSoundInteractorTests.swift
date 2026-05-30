@testable import HappySpeech
import XCTest

// MARK: - ColorAndSoundInteractorTests
//
// ColorAndSoundInteractor is a thin VIP MVP variant (@Observable). Tests cover
// toggle() flipping the isMatched flag, recording the last selectedId, the
// unknown-id guard, and that toggling is non-destructive to other pairs.

@MainActor
final class ColorAndSoundInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> ColorAndSoundInteractor {
        ColorAndSoundInteractor(childId: childId)
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-color")
        XCTAssertEqual(sut.childId, "kid-color")
    }

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_noSelection() {
        let sut = makeSUT()
        XCTAssertNil(sut.state.selectedId)
    }

    func test_initialState_nothingMatched() {
        let sut = makeSUT()
        XCTAssertTrue(sut.state.pairs.allSatisfy { !$0.isMatched })
    }

    func test_initialState_hasSixPairs() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.pairs.count, 6)
    }

    func test_initialState_pairIdsAreUnique() {
        let sut = makeSUT()
        let ids = sut.state.pairs.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    // MARK: - toggle

    func test_toggle_marksPair() {
        let sut = makeSUT()
        let id = sut.state.pairs[0].id
        sut.toggle(id)
        XCTAssertTrue(sut.state.pairs[0].isMatched)
    }

    func test_toggle_setsSelectedId() {
        let sut = makeSUT()
        let id = sut.state.pairs[2].id
        sut.toggle(id)
        XCTAssertEqual(sut.state.selectedId, id)
    }

    func test_toggle_twice_unmarksPair() {
        let sut = makeSUT()
        let id = sut.state.pairs[0].id
        sut.toggle(id)
        sut.toggle(id)
        XCTAssertFalse(sut.state.pairs[0].isMatched)
    }

    func test_toggle_twice_selectedIdStillSet() {
        let sut = makeSUT()
        let id = sut.state.pairs[0].id
        sut.toggle(id)
        sut.toggle(id)
        // selectedId tracks the last tapped pair regardless of matched state.
        XCTAssertEqual(sut.state.selectedId, id)
    }

    func test_toggle_doesNotAffectOtherPairs() {
        let sut = makeSUT()
        let target = sut.state.pairs[1].id
        sut.toggle(target)
        for pair in sut.state.pairs where pair.id != target {
            XCTAssertFalse(pair.isMatched, "Pair \(pair.id) should remain unmatched")
        }
    }

    func test_toggle_unknownId_noChange() {
        let sut = makeSUT()
        sut.toggle("nonexistent")
        XCTAssertNil(sut.state.selectedId)
        XCTAssertTrue(sut.state.pairs.allSatisfy { !$0.isMatched })
    }

    func test_toggle_changingSelection_updatesSelectedId() {
        let sut = makeSUT()
        let first = sut.state.pairs[0].id
        let second = sut.state.pairs[1].id
        sut.toggle(first)
        sut.toggle(second)
        XCTAssertEqual(sut.state.selectedId, second)
    }

    func test_toggle_allPairs_marksEverything() {
        let sut = makeSUT()
        for pair in sut.state.pairs {
            sut.toggle(pair.id)
        }
        XCTAssertTrue(sut.state.pairs.allSatisfy(\.isMatched))
    }
}
