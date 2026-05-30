@testable import HappySpeech
import XCTest

// MARK: - SoundJournalKidInteractorTests
//
// SoundJournalKidInteractor is a thin VIP MVP variant (@Observable). The only
// behaviour is select(_:) which toggles the selected entry id.

@MainActor
final class SoundJournalKidInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> SoundJournalKidInteractor {
        SoundJournalKidInteractor(childId: childId)
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-7")
        XCTAssertEqual(sut.childId, "kid-7")
    }

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_noEntrySelected() {
        let sut = makeSUT()
        XCTAssertNil(sut.state.selectedEntryId)
    }

    func test_initialState_seedEntriesPresent() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.entries.count, 5)
        XCTAssertEqual(sut.state.entries.first?.sound, "Р")
    }

    // MARK: - select

    func test_select_setsSelectedEntryId() {
        let sut = makeSUT()
        sut.select("e2")
        XCTAssertEqual(sut.state.selectedEntryId, "e2")
    }

    func test_select_sameId_togglesOff() {
        let sut = makeSUT()
        sut.select("e3")
        sut.select("e3")
        XCTAssertNil(sut.state.selectedEntryId)
    }

    func test_select_differentId_replacesSelection() {
        let sut = makeSUT()
        sut.select("e1")
        sut.select("e4")
        XCTAssertEqual(sut.state.selectedEntryId, "e4")
    }

    func test_select_unknownId_stillStoresIt() {
        // Interactor does not validate against entries — it simply toggles the id.
        let sut = makeSUT()
        sut.select("does-not-exist")
        XCTAssertEqual(sut.state.selectedEntryId, "does-not-exist")
    }

    func test_select_doesNotMutateEntries() {
        let sut = makeSUT()
        let before = sut.state.entries
        sut.select("e2")
        XCTAssertEqual(sut.state.entries, before)
    }
}
