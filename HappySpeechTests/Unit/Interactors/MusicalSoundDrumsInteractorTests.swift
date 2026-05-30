@testable import HappySpeech
import XCTest

// MARK: - MusicalSoundDrumsInteractorTests
//
// MusicalSoundDrumsInteractor is a thin VIP MVP variant (@Observable). tap()
// counts beats and records the last drum hit; reset() zeroes the counter and
// clears the last drum. Tests cover counting, last-drum tracking and reset.

@MainActor
final class MusicalSoundDrumsInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> MusicalSoundDrumsInteractor {
        MusicalSoundDrumsInteractor(childId: childId)
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-drum")
        XCTAssertEqual(sut.childId, "kid-drum")
    }

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_zeroBeats() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.beatsCount, 0)
    }

    func test_initialState_noLastDrum() {
        let sut = makeSUT()
        XCTAssertNil(sut.state.lastDrumId)
    }

    func test_initialState_hasRhythmPattern() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.rhythmPattern, [.low, .mid, .high])
    }

    func test_initialState_hasTargetPhoneme() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.targetPhoneme.isEmpty)
    }

    // MARK: - tap

    func test_tap_incrementsBeatCount() {
        let sut = makeSUT()
        sut.tap(.mid)
        XCTAssertEqual(sut.state.beatsCount, 1)
    }

    func test_tap_recordsLastDrum() {
        let sut = makeSUT()
        sut.tap(.high)
        XCTAssertEqual(sut.state.lastDrumId, .high)
    }

    func test_tap_multipleTimes_accumulates() {
        let sut = makeSUT()
        sut.tap(.low)
        sut.tap(.mid)
        sut.tap(.high)
        XCTAssertEqual(sut.state.beatsCount, 3)
    }

    func test_tap_lastDrumReflectsMostRecent() {
        let sut = makeSUT()
        sut.tap(.low)
        sut.tap(.high)
        XCTAssertEqual(sut.state.lastDrumId, .high)
    }

    func test_tap_allDrumKinds_noCrash() {
        let sut = makeSUT()
        for drum in MusicalSoundDrumsModels.DrumId.allCases {
            sut.tap(drum)
        }
        XCTAssertEqual(sut.state.beatsCount, MusicalSoundDrumsModels.DrumId.allCases.count)
    }

    func test_tap_doesNotChangeTargetOrPattern() {
        let sut = makeSUT()
        sut.tap(.mid)
        XCTAssertEqual(sut.state.targetPhoneme, MusicalSoundDrumsModels.ViewState.initial.targetPhoneme)
        XCTAssertEqual(sut.state.rhythmPattern, MusicalSoundDrumsModels.ViewState.initial.rhythmPattern)
    }

    // MARK: - reset

    func test_reset_zeroesBeatCount() {
        let sut = makeSUT()
        sut.tap(.low)
        sut.tap(.mid)
        sut.reset()
        XCTAssertEqual(sut.state.beatsCount, 0)
    }

    func test_reset_clearsLastDrum() {
        let sut = makeSUT()
        sut.tap(.high)
        sut.reset()
        XCTAssertNil(sut.state.lastDrumId)
    }

    func test_reset_keepsTargetAndPattern() {
        let sut = makeSUT()
        sut.tap(.low)
        sut.reset()
        XCTAssertEqual(sut.state.targetPhoneme, MusicalSoundDrumsModels.ViewState.initial.targetPhoneme)
        XCTAssertEqual(sut.state.rhythmPattern, MusicalSoundDrumsModels.ViewState.initial.rhythmPattern)
    }
}
