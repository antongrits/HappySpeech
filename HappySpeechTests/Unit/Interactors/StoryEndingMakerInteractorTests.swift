@testable import HappySpeech
import XCTest

// MARK: - StoryEndingMakerInteractorTests
//
// StoryEndingMakerInteractor is a thin VIP MVP variant (@Observable). It drives a
// three-phase flow: choosing → (select a card) → recording → (save) → saved, with
// reset() returning to the start. Tests cover the phase transitions, selection
// tracking and reset.

@MainActor
final class StoryEndingMakerInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> StoryEndingMakerInteractor {
        StoryEndingMakerInteractor(childId: childId)
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-story")
        XCTAssertEqual(sut.childId, "kid-story")
    }

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_phaseChoosing() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.phase, .choosing)
    }

    func test_initialState_noSelection() {
        let sut = makeSUT()
        XCTAssertNil(sut.state.selectedId)
    }

    func test_initialState_cardsWellFormed() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.cards.isEmpty)
        XCTAssertEqual(Set(sut.state.cards.map(\.id)).count, sut.state.cards.count)
        for card in sut.state.cards {
            XCTAssertFalse(card.label.isEmpty)
            XCTAssertFalse(card.emoji.isEmpty)
        }
    }

    // MARK: - select

    func test_select_recordsSelectedId() {
        let sut = makeSUT()
        let id = sut.state.cards[1].id
        sut.select(id)
        XCTAssertEqual(sut.state.selectedId, id)
    }

    func test_select_movesToRecordingPhase() {
        let sut = makeSUT()
        sut.select(sut.state.cards[0].id)
        XCTAssertEqual(sut.state.phase, .recording)
    }

    func test_select_canChangeSelection() {
        let sut = makeSUT()
        sut.select(sut.state.cards[0].id)
        let second = sut.state.cards[2].id
        sut.select(second)
        XCTAssertEqual(sut.state.selectedId, second)
        XCTAssertEqual(sut.state.phase, .recording)
    }

    // MARK: - save

    func test_save_movesToSavedPhase() {
        let sut = makeSUT()
        sut.select(sut.state.cards[0].id)
        sut.save()
        XCTAssertEqual(sut.state.phase, .saved)
    }

    func test_save_keepsSelection() {
        let sut = makeSUT()
        let id = sut.state.cards[0].id
        sut.select(id)
        sut.save()
        XCTAssertEqual(sut.state.selectedId, id)
    }

    // MARK: - reset

    func test_reset_restoresInitialState() {
        let sut = makeSUT()
        sut.select(sut.state.cards[0].id)
        sut.save()
        sut.reset()
        XCTAssertEqual(sut.state, .initial)
        XCTAssertEqual(sut.state.phase, .choosing)
        XCTAssertNil(sut.state.selectedId)
    }
}
