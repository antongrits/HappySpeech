@testable import HappySpeech
import XCTest

// MARK: - AudioMemoryGameInteractorTests
//
// AudioMemoryGameInteractor is a thin VIP MVP variant (@Observable) implementing
// a memory-match game. Tests cover first/second pick, matching, mismatch (with
// the 700ms flip-back), move counting, completion and restart. The deck is
// shuffled, so tests locate tiles by pairKey rather than by fixed index.

@MainActor
final class AudioMemoryGameInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> AudioMemoryGameInteractor {
        AudioMemoryGameInteractor(childId: childId)
    }

    /// Indices of the two tiles that share the given pairKey.
    private func pairIndices(_ sut: AudioMemoryGameInteractor, key: String) -> (Int, Int) {
        let indices = sut.tiles.indices.filter { sut.tiles[$0].pairKey == key }
        return (indices[0], indices[1])
    }

    /// Two indices whose pairKeys differ.
    private func mismatchIndices(_ sut: AudioMemoryGameInteractor) -> (Int, Int) {
        let firstKey = sut.tiles[0].pairKey
        let other = sut.tiles.indices.first { sut.tiles[$0].pairKey != firstKey }!
        return (0, other)
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-5")
        XCTAssertEqual(sut.childId, "kid-5")
    }

    func test_initialDeck_hasTwelveTiles() {
        let sut = makeSUT()
        XCTAssertEqual(sut.tiles.count, AudioMemoryGameModels.pairKeys.count * 2)
    }

    func test_initialDeck_hasExactlyTwoOfEachPair() {
        let sut = makeSUT()
        for key in AudioMemoryGameModels.pairKeys {
            XCTAssertEqual(sut.tiles.filter { $0.pairKey == key }.count, 2)
        }
    }

    func test_initialState_noPickNoMovesNotComplete() {
        let sut = makeSUT()
        XCTAssertNil(sut.firstPickIndex)
        XCTAssertEqual(sut.moves, 0)
        XCTAssertEqual(sut.matchedCount, 0)
        XCTAssertFalse(sut.isComplete)
        XCTAssertFalse(sut.isResolving)
    }

    // MARK: - First pick

    func test_tap_firstPick_flipsTileAndStoresIndex() {
        let sut = makeSUT()
        sut.tap(at: 0)
        XCTAssertTrue(sut.tiles[0].isFlipped)
        XCTAssertEqual(sut.firstPickIndex, 0)
        XCTAssertEqual(sut.moves, 0) // first pick does not count a move
    }

    func test_tap_sameTileTwice_isIgnoredOnSecond() {
        let sut = makeSUT()
        sut.tap(at: 0)
        sut.tap(at: 0) // already flipped → guard rejects
        XCTAssertEqual(sut.firstPickIndex, 0)
        XCTAssertEqual(sut.moves, 0)
    }

    // MARK: - Matching

    func test_tap_matchingPair_marksMatchedAndCountsMove() {
        let sut = makeSUT()
        let (a, b) = pairIndices(sut, key: "С")
        sut.tap(at: a)
        sut.tap(at: b)
        XCTAssertTrue(sut.tiles[a].isMatched)
        XCTAssertTrue(sut.tiles[b].isMatched)
        XCTAssertEqual(sut.matchedCount, 1)
        XCTAssertEqual(sut.moves, 1)
        XCTAssertNil(sut.firstPickIndex)
        XCTAssertFalse(sut.isResolving)
    }

    func test_tap_matchedTile_cannotBePickedAgain() {
        let sut = makeSUT()
        let (a, b) = pairIndices(sut, key: "Ш")
        sut.tap(at: a)
        sut.tap(at: b)
        // Tap the already-matched tile → guard rejects, no new firstPick.
        sut.tap(at: a)
        XCTAssertNil(sut.firstPickIndex)
    }

    // MARK: - Mismatch (async flip-back)

    func test_tap_mismatch_entersResolvingThenFlipsBack() async {
        let sut = makeSUT()
        let (a, b) = mismatchIndices(sut)
        sut.tap(at: a)
        sut.tap(at: b)
        // Immediately after second tap: move counted, resolving, both flipped, no match.
        XCTAssertEqual(sut.moves, 1)
        XCTAssertTrue(sut.isResolving)
        XCTAssertEqual(sut.matchedCount, 0)

        // Wait past the 700ms flip-back window.
        try? await Task.sleep(for: .milliseconds(900))
        XCTAssertFalse(sut.isResolving)
        XCTAssertFalse(sut.tiles[a].isFlipped)
        XCTAssertFalse(sut.tiles[b].isFlipped)
        XCTAssertNil(sut.firstPickIndex)
    }

    func test_tap_whileResolving_isIgnored() async {
        let sut = makeSUT()
        let (a, b) = mismatchIndices(sut)
        sut.tap(at: a)
        sut.tap(at: b)
        XCTAssertTrue(sut.isResolving)
        // Try to pick a third tile while resolving — should be ignored.
        let third = sut.tiles.indices.first { $0 != a && $0 != b }!
        sut.tap(at: third)
        XCTAssertFalse(sut.tiles[third].isFlipped)
        try? await Task.sleep(for: .milliseconds(900))
    }

    // MARK: - Completion

    func test_matchingAllPairs_setsComplete() {
        let sut = makeSUT()
        for key in AudioMemoryGameModels.pairKeys {
            let (a, b) = pairIndices(sut, key: key)
            sut.tap(at: a)
            sut.tap(at: b)
        }
        XCTAssertTrue(sut.isComplete)
        XCTAssertEqual(sut.matchedCount, AudioMemoryGameModels.pairKeys.count)
        XCTAssertEqual(sut.moves, AudioMemoryGameModels.pairKeys.count)
    }

    // MARK: - Bounds / edge

    func test_tap_outOfBoundsIndex_isIgnored() {
        let sut = makeSUT()
        sut.tap(at: 999)
        XCTAssertNil(sut.firstPickIndex)
        XCTAssertEqual(sut.moves, 0)
    }

    // MARK: - Restart

    func test_restart_resetsAllState() {
        let sut = makeSUT()
        let (a, b) = pairIndices(sut, key: "Р")
        sut.tap(at: a)
        sut.tap(at: b)
        sut.restart()
        XCTAssertEqual(sut.matchedCount, 0)
        XCTAssertEqual(sut.moves, 0)
        XCTAssertNil(sut.firstPickIndex)
        XCTAssertFalse(sut.isResolving)
        XCTAssertFalse(sut.isComplete)
        XCTAssertTrue(sut.tiles.allSatisfy { !$0.isFlipped && !$0.isMatched })
    }
}
