@testable import HappySpeech
import XCTest

// MARK: - WhisperGameInteractorTests
//
// WhisperGameInteractor (@Observable). setMode() only switches the target mode —
// currentLevel is measured for real from the microphone RMS during a round (no
// Double.random simulation). Without a recording session currentLevel stays at
// the initial value. Tests verify mode switching, that setMode does not fabricate
// a level, the matchAccuracy computed property, and round counting.

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

    func test_setMode_doesNotFabricateLevel() {
        // setMode только переключает целевой режим. currentLevel НЕ симулируется
        // (никакого Double.random) — он остаётся прежним до реального замера
        // микрофона. Без записи он равен начальному значению.
        let sut = makeSUT()
        let initialLevel = sut.state.currentLevel
        for mode in WhisperGameModels.Mode.allCases {
            sut.setMode(mode)
            XCTAssertEqual(sut.state.mode, mode)
            XCTAssertEqual(
                sut.state.currentLevel, initialLevel, accuracy: 0.0001,
                "setMode не должен подменять измеренный уровень для \(mode.rawValue)"
            )
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

    func test_matchAccuracy_reflectsMeasuredLevel_notMode() {
        // matchAccuracy зависит ТОЛЬКО от реально измеренного currentLevel
        // относительно targetLevel режима. setMode не «подгоняет» уровень, поэтому
        // после переключения на .normal (target 0.55) при начальном уровне 0.18
        // точность низкая — это честное поведение без симуляции.
        let sut = makeSUT()
        sut.setMode(.normal)
        let delta = abs(sut.state.currentLevel - WhisperGameModels.Mode.normal.targetLevel)
        let expected = max(0, 1 - delta * 2)
        XCTAssertEqual(sut.state.matchAccuracy, expected, accuracy: 0.0001)
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
