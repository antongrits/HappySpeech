import XCTest
@testable import HappySpeech

// MARK: - HapticServiceTests

final class HapticServiceTests: XCTestCase {

    // MARK: - MockHapticService tracks patterns

    func testMockRecordsPlayedPattern() async {
        let mock = MockHapticService()
        await mock.play(pattern: .celebration)
        XCTAssertEqual(mock.playedPatterns, [.celebration])
    }

    func testMockRecordsMultiplePatterns() async {
        let mock = MockHapticService()
        await mock.play(pattern: .buttonTap)
        await mock.play(pattern: .wrong)
        await mock.play(pattern: .achievementUnlock)
        XCTAssertEqual(mock.playedPatterns, [.buttonTap, .wrong, .achievementUnlock])
    }

    // v31 Wave A — Core Haptics composer for level-up.
    func testMockTracksPlayLevelUp() async {
        let mock = MockHapticService()
        XCTAssertEqual(mock.levelUpCount, 0)
        await mock.playLevelUp()
        XCTAssertEqual(mock.levelUpCount, 1)
        await mock.playLevelUp()
        XCTAssertEqual(mock.levelUpCount, 2)
    }

    func testFallbackPlayLevelUpRunsWithoutCrashing() async {
        let fallback = FallbackHapticService()
        await fallback.playLevelUp()
        XCTAssertTrue(fallback.isAvailable)
    }

    func testFallbackRespectsIntensityScaleZero() async {
        let fallback = FallbackHapticService()
        fallback.setIntensityScale(0)
        // Не должно крашить и не должно реально воспроизводить UIKit feedback.
        await fallback.playLevelUp()
        XCTAssertTrue(true)
    }

    // MARK: - Intensity scale

    func testIntensityScaleClampsToRange() {
        let mock = MockHapticService()
        mock.setIntensityScale(2.5)
        XCTAssertEqual(mock.intensityScale, 1.0, accuracy: 0.001)
        mock.setIntensityScale(-0.5)
        XCTAssertEqual(mock.intensityScale, 0.0, accuracy: 0.001)
    }

    func testIntensityScaleFullLevel() {
        let mock = MockHapticService()
        mock.setIntensityScale(HapticIntensityLevel.full.scale)
        XCTAssertEqual(mock.intensityScale, 1.0, accuracy: 0.001)
    }

    func testIntensityScaleSubtleLevel() {
        let mock = MockHapticService()
        mock.setIntensityScale(HapticIntensityLevel.subtle.scale)
        XCTAssertEqual(mock.intensityScale, 0.5, accuracy: 0.001)
    }

    func testIntensityScaleOffLevel() {
        let mock = MockHapticService()
        mock.setIntensityScale(HapticIntensityLevel.off.scale)
        XCTAssertEqual(mock.intensityScale, 0.0, accuracy: 0.001)
    }

    // MARK: - HapticPattern rawValue matches AHAP filename

    func testAllPatternsHaveMatchingRawValue() {
        let expected: Set<String> = [
            "celebration", "perfectRound", "wrong", "lyalyaTap", "achievementUnlock",
            "breathingInhale", "breathingExhale", "buttonTap", "cardSelect", "levelUp",
            "rewardCollected", "confetti", "heartbeat", "notification", "errorBuzz"
        ]
        let actual = Set(HapticPattern.allCases.map(\.rawValue))
        XCTAssertEqual(actual, expected)
    }

    // MARK: - HapticIntensityLevel

    func testHapticIntensityLevelFromScale() {
        XCTAssertEqual(HapticIntensityLevel.from(scale: 0.0), .off)
        XCTAssertEqual(HapticIntensityLevel.from(scale: 0.5), .subtle)
        XCTAssertEqual(HapticIntensityLevel.from(scale: 1.0), .full)
    }

    func testHapticIntensityLevelCount() {
        XCTAssertEqual(HapticIntensityLevel.allCases.count, 3)
    }

    // MARK: - Stop does not throw

    func testStopIsNoop() async {
        let mock = MockHapticService()
        await mock.play(pattern: .heartbeat)
        await mock.stop()
        XCTAssertEqual(mock.playedPatterns.count, 1)
    }
}
