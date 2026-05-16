@testable import HappySpeech
import UIKit
import XCTest

// MARK: - MockHapticService

private final class MockHapticService: HapticService, @unchecked Sendable {
    private(set) var patterns: [HapticPattern] = []
    var isAvailable: Bool = true

    func play(pattern: HapticPattern) async {
        patterns.append(pattern)
    }

    func setIntensityScale(_ scale: Float) {}

    func stop() async {}

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {}
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {}
    func selection() {}
}

// MARK: - GrammarFeedbackWorkerTests

@MainActor
final class GrammarFeedbackWorkerTests: XCTestCase {

    private var mockHaptic: MockHapticService!
    private var sut: GrammarFeedbackWorker!

    override func setUp() {
        super.setUp()
        mockHaptic = MockHapticService()
        sut = GrammarFeedbackWorker(hapticService: mockHaptic)
    }

    override func tearDown() {
        sut.stopSpeaking()
        sut = nil
        mockHaptic = nil
        super.tearDown()
    }

    // MARK: - Haptic: selection

    func test_playSelectionHaptic_triggersCardSelect() async throws {
        sut.playSelectionHaptic()
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(mockHaptic.patterns.last, .cardSelect,
                       "playSelectionHaptic должен вызвать .cardSelect")
    }

    // MARK: - Haptic: success

    func test_playSuccessHaptic_triggersPerfectRound() async throws {
        sut.playSuccessHaptic()
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(mockHaptic.patterns.last, .perfectRound,
                       "playSuccessHaptic должен вызвать .perfectRound")
    }

    // MARK: - Haptic: error

    func test_playErrorHaptic_triggersWrong() async throws {
        sut.playErrorHaptic()
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(mockHaptic.patterns.last, .wrong,
                       "playErrorHaptic должен вызвать .wrong")
    }

    // MARK: - playSuccessSound

    func test_playSuccessSound_triggersPerfectRound() async throws {
        sut.playSuccessSound()
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(mockHaptic.patterns.contains(.perfectRound),
                      "playSuccessSound должен задействовать .perfectRound")
    }

    // MARK: - playErrorSound

    func test_playErrorSound_triggersWrong() async throws {
        sut.playErrorSound()
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(mockHaptic.patterns.contains(.wrong),
                      "playErrorSound должен задействовать .wrong")
    }

    // MARK: - speakLevelComplete: routing does not crash

    func test_speakLevelComplete_doesNotCrash_easy() {
        XCTAssertNoThrow(sut.speakLevelComplete(difficulty: "easy"))
    }

    func test_speakLevelComplete_doesNotCrash_medium() {
        XCTAssertNoThrow(sut.speakLevelComplete(difficulty: "medium"))
    }

    func test_speakLevelComplete_doesNotCrash_hard() {
        XCTAssertNoThrow(sut.speakLevelComplete(difficulty: "hard"))
    }

    func test_speakLevelComplete_doesNotCrash_unknownDifficulty() {
        XCTAssertNoThrow(sut.speakLevelComplete(difficulty: "legendary"))
    }

    // MARK: - stopSpeaking: idempotent

    func test_stopSpeaking_calledTwice_doesNotCrash() {
        sut.stopSpeaking()
        XCTAssertNoThrow(sut.stopSpeaking())
    }
}
