@testable import HappySpeech
import XCTest

// MARK: - PacingInteractorTests
//
// PacingInteractor не имеет отдельного Presenter/DisplayLogic — использует
// @Observable Display как прямую state-машину. Тесты работают с
// sut.display напрямую и используют test-хуки (_test_advanceBeat,
// _test_loadCurrentPhrase, _test_beatInterval) которые доступны в DEBUG.

@MainActor
final class PacingInteractorTests: XCTestCase {

    private func makeSUT() -> PacingInteractor {
        PacingInteractor(hapticService: SpyHapticService())
    }

    // MARK: - startSession

    func test_startSession_easy_syllablesNonEmpty() {
        let sut = makeSUT()
        sut.startSession(difficulty: .easy)
        XCTAssertFalse(sut.display.syllables.isEmpty)
    }

    func test_startSession_medium_syllablesNonEmpty() {
        let sut = makeSUT()
        sut.startSession(difficulty: .medium)
        XCTAssertFalse(sut.display.syllables.isEmpty)
    }

    func test_startSession_hard_syllablesNonEmpty() {
        let sut = makeSUT()
        sut.startSession(difficulty: .hard)
        XCTAssertFalse(sut.display.syllables.isEmpty)
    }

    func test_startSession_setsIsRunningFalse() {
        let sut = makeSUT()
        sut.startSession(difficulty: .easy)
        XCTAssertFalse(sut.display.isRunning)
    }

    func test_startSession_setsIsSessionCompleteFalse() {
        let sut = makeSUT()
        sut.startSession(difficulty: .easy)
        XCTAssertFalse(sut.display.isSessionComplete)
    }

    func test_startSession_activeSyllableIndexIsMinusOne() {
        let sut = makeSUT()
        sut.startSession(difficulty: .easy)
        XCTAssertEqual(sut.display.activeSyllableIndex, -1)
    }

    func test_startSession_phraseTextIsNonEmpty() {
        let sut = makeSUT()
        sut.startSession(difficulty: .easy)
        XCTAssertFalse(sut.display.phraseText.isEmpty)
    }

    func test_startSession_progressLabelIsNonEmpty() {
        let sut = makeSUT()
        sut.startSession(difficulty: .easy)
        XCTAssertFalse(sut.display.progressLabel.isEmpty)
    }

    func test_startSession_sliderProgressIsZero() {
        let sut = makeSUT()
        sut.startSession(difficulty: .easy)
        XCTAssertEqual(sut.display.sliderProgress, 0.0, accuracy: 0.001)
    }

    func test_startSession_showRoundRewardFalse() {
        let sut = makeSUT()
        sut.startSession(difficulty: .easy)
        XCTAssertFalse(sut.display.showRoundReward)
    }

    // MARK: - play / pause / stop

    func test_play_setsIsRunningTrue() {
        let sut = makeSUT()
        sut.startSession(difficulty: .easy)
        sut.play()
        XCTAssertTrue(sut.display.isRunning)
    }

    func test_play_clearsPausedFlag() {
        let sut = makeSUT()
        sut.startSession(difficulty: .easy)
        sut.play()
        XCTAssertFalse(sut.display.isPaused)
    }

    func test_play_whenAlreadyRunning_doesNotDouble() {
        let sut = makeSUT()
        sut.startSession(difficulty: .easy)
        sut.play()
        let wasRunning = sut.display.isRunning
        sut.play()
        XCTAssertTrue(wasRunning)
        XCTAssertTrue(sut.display.isRunning)
    }

    func test_pause_stopsRunningSetsPaused() {
        let sut = makeSUT()
        sut.startSession(difficulty: .easy)
        sut.play()
        sut.pause()
        XCTAssertFalse(sut.display.isRunning)
        XCTAssertTrue(sut.display.isPaused)
    }

    func test_stop_clearsRunningAndPaused() {
        let sut = makeSUT()
        sut.startSession(difficulty: .easy)
        sut.play()
        sut.stop()
        XCTAssertFalse(sut.display.isRunning)
        XCTAssertFalse(sut.display.isPaused)
    }

    func test_stop_resetsActiveSyllableIndexToMinusOne() {
        let sut = makeSUT()
        sut.startSession(difficulty: .easy)
        sut._test_advanceBeat()
        sut.stop()
        XCTAssertEqual(sut.display.activeSyllableIndex, -1)
    }

    func test_stop_resetsSliderProgressToZero() {
        let sut = makeSUT()
        sut.startSession(difficulty: .easy)
        sut._test_advanceBeat()
        sut.stop()
        XCTAssertEqual(sut.display.sliderProgress, 0.0, accuracy: 0.001)
    }

    // MARK: - advanceBeat (via test hook)

    func test_advanceBeat_setsActiveSyllableIndexToZero() {
        let sut = makeSUT()
        sut.startSession(difficulty: .easy)
        sut._test_advanceBeat()
        XCTAssertEqual(sut.display.activeSyllableIndex, 0)
    }

    func test_advanceBeat_sliderProgressIsGreaterThanZero() {
        let sut = makeSUT()
        sut.startSession(difficulty: .easy)
        sut._test_advanceBeat()
        XCTAssertGreaterThan(sut.display.sliderProgress, 0.0)
    }

    func test_advanceBeat_firstSyllableStateIsActive() {
        let sut = makeSUT()
        sut.startSession(difficulty: .easy)
        sut._test_advanceBeat()
        XCTAssertEqual(sut.display.syllables.first?.state, .active)
    }

    func test_advanceBeat_twice_firstSyllableIsSpoken() {
        let sut = makeSUT()
        sut.startSession(difficulty: .easy)
        sut._test_advanceBeat()
        sut._test_advanceBeat()
        XCTAssertEqual(sut.display.syllables[0].state, .spoken)
    }

    // MARK: - Beat interval (timing)

    func test_beatInterval_easy_isSlowerThanMedium() {
        let sut = makeSUT()
        let easy = sut._test_beatInterval(for: .easy)
        let medium = sut._test_beatInterval(for: .medium)
        XCTAssertGreaterThan(easy, medium)
    }

    func test_beatInterval_medium_isSlowerThanHard() {
        let sut = makeSUT()
        let medium = sut._test_beatInterval(for: .medium)
        let hard = sut._test_beatInterval(for: .hard)
        XCTAssertGreaterThan(medium, hard)
    }

    func test_beatInterval_easy_isApproximately65BPM() {
        let sut = makeSUT()
        let expected = 60.0 / 65.0
        XCTAssertEqual(sut._test_beatInterval(for: .easy), expected, accuracy: 0.001)
    }

    func test_beatInterval_medium_isApproximately80BPM() {
        let sut = makeSUT()
        let expected = 60.0 / 80.0
        XCTAssertEqual(sut._test_beatInterval(for: .medium), expected, accuracy: 0.001)
    }

    func test_beatInterval_hard_isApproximately95BPM() {
        let sut = makeSUT()
        let expected = 60.0 / 95.0
        XCTAssertEqual(sut._test_beatInterval(for: .hard), expected, accuracy: 0.001)
    }

    // MARK: - Session complete guard

    func test_play_afterSessionComplete_doesNotSetRunning() {
        let sut = makeSUT()
        sut.startSession(difficulty: .easy)
        // Force session complete state directly.
        sut.display.isSessionComplete = true
        sut.play()
        XCTAssertFalse(sut.display.isRunning)
    }

    // MARK: - syllable state coverage

    func test_startSession_allSyllablesInitiallyWaiting() {
        let sut = makeSUT()
        sut.startSession(difficulty: .easy)
        for syllable in sut.display.syllables {
            XCTAssertEqual(syllable.state, .waiting, "syllable \(syllable.index) should be .waiting")
        }
    }

    func test_stop_afterAdvance_resetsAllSyllablesToWaiting() {
        let sut = makeSUT()
        sut.startSession(difficulty: .easy)
        sut._test_advanceBeat()
        sut._test_advanceBeat()
        sut.stop()
        for syllable in sut.display.syllables {
            XCTAssertEqual(syllable.state, .waiting, "syllable \(syllable.index) should be reset to .waiting")
        }
    }
}
