@testable import HappySpeech
import XCTest

// MARK: - TongueTwisterArenaInteractorTests
//
// TongueTwisterArenaInteractor is a thin VIP MVP variant (@Observable). Tests
// cover select() (which also clears recording), back() (deselect + stop), and
// toggleRecord() flipping the recording flag.

@MainActor
final class TongueTwisterArenaInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> TongueTwisterArenaInteractor {
        TongueTwisterArenaInteractor(childId: childId)
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-arena")
        XCTAssertEqual(sut.childId, "kid-arena")
    }

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_noSelection() {
        let sut = makeSUT()
        XCTAssertNil(sut.state.selected)
    }

    func test_initialState_notRecording() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.isRecording)
    }

    func test_initialState_hasEightTwisters() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.twisters.count, 8)
    }

    func test_initialState_twisterIdsAreUnique() {
        let sut = makeSUT()
        let ids = sut.state.twisters.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    // MARK: - select

    func test_select_setsSelectedTwister() {
        let sut = makeSUT()
        let twister = sut.state.twisters[3]
        sut.select(twister)
        XCTAssertEqual(sut.state.selected, twister)
    }

    func test_select_clearsRecording() {
        let sut = makeSUT()
        sut.toggleRecord()
        XCTAssertTrue(sut.state.isRecording)
        sut.select(sut.state.twisters[0])
        XCTAssertFalse(sut.state.isRecording)
    }

    func test_select_changingSelection_updatesTwister() {
        let sut = makeSUT()
        sut.select(sut.state.twisters[0])
        sut.select(sut.state.twisters[1])
        XCTAssertEqual(sut.state.selected, sut.state.twisters[1])
    }

    // MARK: - back

    func test_back_clearsSelection() {
        let sut = makeSUT()
        sut.select(sut.state.twisters[2])
        sut.back()
        XCTAssertNil(sut.state.selected)
    }

    func test_back_stopsRecording() {
        let sut = makeSUT()
        sut.select(sut.state.twisters[0])
        sut.toggleRecord()
        sut.back()
        XCTAssertFalse(sut.state.isRecording)
    }

    func test_back_fromInitialState_noCrash() {
        let sut = makeSUT()
        sut.back()
        XCTAssertNil(sut.state.selected)
        XCTAssertFalse(sut.state.isRecording)
    }

    // MARK: - toggleRecord

    func test_toggleRecord_startsRecording() {
        let sut = makeSUT()
        sut.toggleRecord()
        XCTAssertTrue(sut.state.isRecording)
    }

    func test_toggleRecord_twice_stopsRecording() {
        let sut = makeSUT()
        sut.toggleRecord()
        sut.toggleRecord()
        XCTAssertFalse(sut.state.isRecording)
    }

    func test_toggleRecord_doesNotAffectSelection() {
        let sut = makeSUT()
        sut.select(sut.state.twisters[1])
        sut.toggleRecord()
        XCTAssertEqual(sut.state.selected, sut.state.twisters[1])
    }
}
