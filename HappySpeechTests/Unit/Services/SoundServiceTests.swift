import XCTest
@testable import HappySpeech

// MARK: - SoundServiceTests
//
// Covers the UISound + LyalyaPhrase enum contracts and the MockSoundService
// spy behaviour used throughout other feature tests.
// Does NOT load real audio — file-system / Bundle checks happen in
// HappySpeechUITests/Flows/AudioSmokeUITests (simulator-hosted).
// ==================================================================================

final class SoundServiceTests: XCTestCase {

    // MARK: - UISound enum

    func test_UISound_allCases_haveDistinctRawValues() {
        let values = Set(UISound.allCases.map(\.rawValue))
        XCTAssertEqual(values.count, UISound.allCases.count)
    }

    func test_UISound_allCases_haveSnakeCaseRawValues() {
        for sound in UISound.allCases {
            XCTAssertFalse(sound.rawValue.isEmpty)
            XCTAssertEqual(sound.rawValue, sound.rawValue.lowercased(),
                           "\(sound) rawValue must be lowercase_snake_case")
            XCTAssertFalse(sound.rawValue.contains(" "), "No spaces in \(sound)")
        }
    }

    func test_UISound_coversAllCategories() {
        // Must have a sound for each of the 16 canonical UI events.
        let required: Set<String> = [
            "tap", "correct", "incorrect", "reward", "streak", "level_up",
            "warmup_start", "warmup_end", "complete", "pause", "notification",
            "transition_next", "transition_back", "drag_pick", "drag_drop", "error"
        ]
        let actual = Set(UISound.allCases.map(\.rawValue))
        XCTAssertTrue(required.isSubset(of: actual),
                      "Missing: \(required.subtracting(actual))")
    }

    // MARK: - LyalyaPhrase enum

    func test_LyalyaPhrase_allCases_haveDistinctRawValues() {
        let values = Set(LyalyaPhrase.allCases.map(\.rawValue))
        XCTAssertEqual(values.count, LyalyaPhrase.allCases.count)
    }

    func test_LyalyaPhrase_coverage_atLeast100phrases() {
        XCTAssertGreaterThanOrEqual(
            LyalyaPhrase.allCases.count, 100,
            "Plan requires 100+ Lyalya phrases — got \(LyalyaPhrase.allCases.count)"
        )
    }

    func test_LyalyaPhrase_coreGreetingsPresent() {
        let rawValues = Set(LyalyaPhrase.allCases.map(\.rawValue))
        // A few canonical IDs the TourSteps / SessionShell use by name.
        XCTAssertTrue(rawValues.contains("greeting_01"), "greeting_01 missing")
    }

    // MARK: - MockSoundService

    func test_MockSoundService_playDoesNotCrash() {
        let mock = MockSoundService()
        mock.playUISound(.tap)
        mock.playLyalya(.greeting01)
        XCTAssertFalse(mock.isMuted)
    }

    func test_MockSoundService_muteRoundTrip() {
        let mock = MockSoundService()
        mock.setMuted(true)
        XCTAssertTrue(mock.isMuted)
        mock.setMuted(false)
        XCTAssertFalse(mock.isMuted)
    }

    // MARK: - LiveSoundService init

    func test_LiveSoundService_initDoesNotCrash() {
        // Verifies actor-less lock-based impl initializes cleanly and
        // configureAudioSession swallows any simulator audio session failure.
        let live = LiveSoundService()
        XCTAssertFalse(live.isMuted)
        live.setMuted(true)
        XCTAssertTrue(live.isMuted)
    }
}
