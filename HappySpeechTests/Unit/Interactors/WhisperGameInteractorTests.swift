@testable import HappySpeech
import XCTest

// MARK: - WhisperGameInteractorTests
//
// WhisperGameInteractor is a thin VIP MVP variant (@Observable). setMode() picks
// a mode and simulates a measured currentLevel within ±15% of the mode target;
// completeRound() counts rounds. Tests verify mode switching, the simulated
// level bounds, the matchAccuracy computed and round counting.

@MainActor
final class WhisperGameInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> WhisperGameInteractor {
        WhisperGameInteractor(childId: childId)
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-whisper")
        XCTAssertEqual(sut.childId, "kid-whisper")
    }

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_modeIsWhisper() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.mode, .whisper)
    }

    func test_initialState_zeroRounds() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.roundsCompleted, 0)
    }

    // MARK: - setMode

    func test_setMode_updatesMode() {
        let sut = makeSUT()
        sut.setMode(.loud)
        XCTAssertEqual(sut.state.mode, .loud)
    }

    func test_setMode_setsLevelWithinFifteenPercentOfTarget() {
        let sut = makeSUT()
        for mode in WhisperGameModels.Mode.allCases {
            sut.setMode(mode)
            let lower = mode.targetLevel * 0.85
            let upper = mode.targetLevel * 1.15
            XCTAssertGreaterThanOrEqual(sut.state.currentLevel, lower, "mode \(mode.rawValue) under range")
            XCTAssertLessThanOrEqual(sut.state.currentLevel, upper, "mode \(mode.rawValue) over range")
        }
    }

    func test_setMode_keepsRoundsCount() {
        let sut = makeSUT()
        sut.completeRound()
        sut.setMode(.normal)
        XCTAssertEqual(sut.state.roundsCompleted, 1)
    }

    func test_setMode_allModes_noCrash() {
        let sut = makeSUT()
        for mode in WhisperGameModels.Mode.allCases {
            sut.setMode(mode)
            XCTAssertEqual(sut.state.mode, mode)
        }
    }

    // MARK: - matchAccuracy

    func test_matchAccuracy_perfectMatch_isOne() {
        var state = WhisperGameModels.ViewState.initial
        state.currentLevel = state.mode.targetLevel
        XCTAssertEqual(state.matchAccuracy, 1.0, accuracy: 0.0001)
    }

    func test_matchAccuracy_decreasesWithDelta() {
        var state = WhisperGameModels.ViewState.initial
        state.currentLevel = state.mode.targetLevel + 0.1
        // delta 0.1 → accuracy = 1 - 0.1*2 = 0.8
        XCTAssertEqual(state.matchAccuracy, 0.8, accuracy: 0.0001)
    }

    func test_matchAccuracy_clampedAtZero() {
        var state = WhisperGameModels.ViewState.initial
        state.mode = .whisper          // target 0.20
        state.currentLevel = 0.99       // big delta → would be negative without clamp
        XCTAssertEqual(state.matchAccuracy, 0.0, accuracy: 0.0001)
    }

    func test_matchAccuracy_afterSetMode_isHighGivenTightBounds() {
        let sut = makeSUT()
        sut.setMode(.normal)
        // ±15% on target 0.55 → max delta 0.0825 → accuracy ≥ 1 - 0.165 = 0.835
        XCTAssertGreaterThanOrEqual(sut.state.matchAccuracy, 0.83)
    }

    // MARK: - completeRound

    func test_completeRound_incrementsCount() {
        let sut = makeSUT()
        sut.completeRound()
        XCTAssertEqual(sut.state.roundsCompleted, 1)
    }

    func test_completeRound_multipleTimes_accumulates() {
        let sut = makeSUT()
        for _ in 0..<5 { sut.completeRound() }
        XCTAssertEqual(sut.state.roundsCompleted, 5)
    }

    // MARK: - Mode metadata

    func test_modeTargetLevels_areOrdered() {
        XCTAssertLessThan(WhisperGameModels.Mode.whisper.targetLevel, WhisperGameModels.Mode.normal.targetLevel)
        XCTAssertLessThan(WhisperGameModels.Mode.normal.targetLevel, WhisperGameModels.Mode.loud.targetLevel)
    }
}
