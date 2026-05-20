@testable import HappySpeech
import XCTest

// MARK: - BreathingHapticWorkerTests
//
// Покрывает BreathingHapticWorker через MockHapticService.
// Реальный HapticService использует CoreHaptics (hardware) —
// мокается через протокол HapticService.
//
// Также тестируется MockBreathingHapticWorker (встроенный).

// MARK: - MockHapticService

private final class MockHapticService: HapticService, @unchecked Sendable {
    private(set) var playedPatterns: [HapticPattern] = []
    var isAvailable: Bool = false

    func play(pattern: HapticPattern) async {
        playedPatterns.append(pattern)
    }

    func setIntensityScale(_ scale: Float) {}

    func stop() async {}

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {}

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {}

    func selection() {}
    func playLevelUp() async {}
}

// MARK: - BreathingHapticWorkerTests (live через mock HapticService)

final class BreathingHapticWorkerTests: XCTestCase {

    // Live worker через MockHapticService
    private func makeSUT() -> (BreathingHapticWorker, MockHapticService) {
        let haptic = MockHapticService()
        let sut = BreathingHapticWorker(haptic: haptic)
        return (sut, haptic)
    }

    // MARK: - petalBlown

    func test_petalBlown_playsButtonTapPattern() async {
        let (sut, haptic) = makeSUT()
        sut.petalBlown()
        // Даём Task внутри petalBlown завершиться
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(haptic.playedPatterns.contains(.buttonTap),
                      "petalBlown должен воспроизводить .buttonTap")
    }

    // MARK: - blowStart

    func test_blowStart_playsBreathingExhalePattern() async {
        let (sut, haptic) = makeSUT()
        sut.blowStart()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(haptic.playedPatterns.contains(.breathingExhale),
                      "blowStart должен воспроизводить .breathingExhale")
    }

    // MARK: - inhale

    func test_inhale_playsBreathingInhalePattern() async {
        let (sut, haptic) = makeSUT()
        sut.inhale()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(haptic.playedPatterns.contains(.breathingInhale),
                      "inhale должен воспроизводить .breathingInhale")
    }

    // MARK: - exhale

    func test_exhale_playsBreathingExhalePattern() async {
        let (sut, haptic) = makeSUT()
        sut.exhale()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(haptic.playedPatterns.contains(.breathingExhale),
                      "exhale должен воспроизводить .breathingExhale")
    }

    // MARK: - success

    func test_success_playsCelebrationPattern() async {
        let (sut, haptic) = makeSUT()
        sut.success()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(haptic.playedPatterns.contains(.celebration),
                      "success должен воспроизводить .celebration")
    }

    // MARK: - failure

    func test_failure_playsWrongPattern() async {
        let (sut, haptic) = makeSUT()
        sut.failure()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(haptic.playedPatterns.contains(.wrong),
                      "failure должен воспроизводить .wrong")
    }
}

// MARK: - MockBreathingHapticWorkerTests (встроенный mock)

final class MockBreathingHapticWorkerTests: XCTestCase {

    private var mock: MockBreathingHapticWorker!

    override func setUp() {
        super.setUp()
        mock = MockBreathingHapticWorker()
    }

    func test_petalBlown_incrementsPetalCount() {
        mock.petalBlown()
        mock.petalBlown()
        XCTAssertEqual(mock.petalCount, 2)
    }

    func test_blowStart_incrementsBlowStartCount() {
        mock.blowStart()
        XCTAssertEqual(mock.blowStartCount, 1)
    }

    func test_inhale_incrementsInhaleCount() {
        mock.inhale()
        mock.inhale()
        XCTAssertEqual(mock.inhaleCount, 2)
    }

    func test_exhale_incrementsExhaleCount() {
        mock.exhale()
        XCTAssertEqual(mock.exhaleCount, 1)
    }

    func test_success_incrementsSuccessCount() {
        mock.success()
        mock.success()
        mock.success()
        XCTAssertEqual(mock.successCount, 3)
    }

    func test_failure_incrementsFailureCount() {
        mock.failure()
        XCTAssertEqual(mock.failureCount, 1)
    }

    func test_allCountersStartAtZero() {
        XCTAssertEqual(mock.petalCount, 0)
        XCTAssertEqual(mock.blowStartCount, 0)
        XCTAssertEqual(mock.inhaleCount, 0)
        XCTAssertEqual(mock.exhaleCount, 0)
        XCTAssertEqual(mock.successCount, 0)
        XCTAssertEqual(mock.failureCount, 0)
    }

    func test_independentCounters_afterMultipleCalls() {
        mock.inhale()
        mock.exhale()
        mock.exhale()
        mock.petalBlown()
        XCTAssertEqual(mock.inhaleCount, 1)
        XCTAssertEqual(mock.exhaleCount, 2)
        XCTAssertEqual(mock.petalCount, 1)
        XCTAssertEqual(mock.successCount, 0)
    }
}
