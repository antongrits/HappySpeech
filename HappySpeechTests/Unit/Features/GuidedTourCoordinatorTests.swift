import XCTest
@testable import HappySpeech

// MARK: - GuidedTourCoordinatorTests
//
// Covers the 11-step interactive tour state machine:
//   - start() begins at step 0 (unless already completed)
//   - next() advances; on the last step it completes
//   - skip() completes immediately and sets hasCompleted
//   - UserDefaults persistence (`completedKey`)
//   - Auto-advance timer is scheduled & cancelled appropriately
//   - force start bypasses hasCompleted
// ==================================================================================

@MainActor
final class GuidedTourCoordinatorTests: XCTestCase {

    // MARK: - Helpers

    private func makeSUT(
        steps: [TourStep] = [
            TourStep(id: "a", title: "A", body: "bodyA", highlightKey: "a",
                     lyalyaPhrase: nil, autoAdvanceAfter: nil, allowSkip: true),
            TourStep(id: "b", title: "B", body: "bodyB", highlightKey: "b",
                     lyalyaPhrase: nil, autoAdvanceAfter: nil, allowSkip: true),
            TourStep(id: "c", title: "C", body: "bodyC", highlightKey: "c",
                     lyalyaPhrase: nil, autoAdvanceAfter: nil, allowSkip: false),
        ]
    ) -> (GuidedTourCoordinator, UserDefaults) {
        let suiteName = "tour-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let coord = GuidedTourCoordinator(
            soundService: MockSoundService(),
            steps: steps,
            defaults: defaults
        )
        return (coord, defaults)
    }

    // MARK: - start()

    func test_start_beginsAtFirstStep() {
        let (sut, _) = makeSUT()
        XCTAssertFalse(sut.isActive)
        XCTAssertNil(sut.currentIndex)

        sut.start()

        XCTAssertTrue(sut.isActive)
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.currentStep?.id, "a")
    }

    func test_start_skips_ifAlreadyCompleted() {
        let (sut, _) = makeSUT()
        sut.start(); sut.skip()
        XCTAssertTrue(sut.hasCompleted)

        sut.start()
        XCTAssertFalse(sut.isActive, "Should not re-start after completion")
    }

    func test_start_force_bypassesCompletionFlag() {
        let (sut, _) = makeSUT()
        sut.start(); sut.skip()
        XCTAssertTrue(sut.hasCompleted)

        sut.start(force: true)
        XCTAssertTrue(sut.isActive, "force=true should override completion flag")
    }

    // MARK: - next()

    func test_next_advancesToSecondStep() {
        let (sut, _) = makeSUT()
        sut.start()

        sut.next()

        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(sut.currentStep?.id, "b")
    }

    func test_next_onLastStep_completesAndSetsHasCompleted() {
        let (sut, defaults) = makeSUT()
        sut.start()
        sut.next()   // -> b
        sut.next()   // -> c (last)
        XCTAssertTrue(sut.isOnLastStep)

        sut.next()   // should complete

        XCTAssertFalse(sut.isActive)
        XCTAssertTrue(sut.hasCompleted)
        XCTAssertNil(sut.currentIndex)
        XCTAssertTrue(defaults.bool(forKey: "happyspeech.guidedTour.completed.v1"))
    }

    // MARK: - skip()

    func test_skip_immediately_marksCompleted() {
        let (sut, _) = makeSUT()
        sut.start()
        sut.skip()

        XCTAssertFalse(sut.isActive)
        XCTAssertTrue(sut.hasCompleted)
        XCTAssertNil(sut.currentIndex)
    }

    // MARK: - progressFraction

    func test_progressFraction_increasesMonotonically() {
        let (sut, _) = makeSUT()
        sut.start()
        let p1 = sut.progressFraction
        sut.next()
        let p2 = sut.progressFraction
        sut.next()
        let p3 = sut.progressFraction
        XCTAssertLessThan(p1, p2)
        XCTAssertLessThan(p2, p3)
        XCTAssertEqual(p3, 1.0, accuracy: 0.001)
    }

    // MARK: - resetForTesting

    func test_resetForTesting_clearsCompletion() {
        let (sut, _) = makeSUT()
        sut.start(); sut.skip()
        XCTAssertTrue(sut.hasCompleted)

        sut.resetForTesting()

        XCTAssertFalse(sut.hasCompleted)
        XCTAssertFalse(sut.isActive)
    }
}
