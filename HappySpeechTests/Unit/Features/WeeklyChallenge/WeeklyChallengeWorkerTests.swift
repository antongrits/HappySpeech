import XCTest
@testable import HappySpeech

// MARK: - WeeklyChallengeWorkerTests
//
// Block AA v21 — Smoke tests для доменных моделей WeeklyChallenge.
// WeeklyChallenge не имеет отдельного Worker — персистенция через UserDefaults в Interactor.
// Тесты верифицируют WeeklyChallengeState, DayProgress, WeeklyChallengeKind.

final class WeeklyChallengeWorkerTests: XCTestCase {

    // MARK: - Tests

    func test_weeklyChallengeState_isCompleted_whenEnoughDays() {
        let state = WeeklyChallengeState(
            kind: .soundStreak,
            weekStart: Date(),
            dayStates: Array(repeating: .completed, count: 7),
            completed: 7,
            totalRequired: 7
        )
        XCTAssertTrue(state.isCompleted)
        XCTAssertEqual(state.progress, 1.0, accuracy: 0.001)
    }

    func test_weeklyChallengeState_isNotCompleted_whenPartial() {
        let state = WeeklyChallengeState(
            kind: .lessonCount,
            weekStart: Date(),
            dayStates: [.completed, .completed, .pending, .locked, .locked, .locked, .locked],
            completed: 2,
            totalRequired: 5
        )
        XCTAssertFalse(state.isCompleted)
        XCTAssertEqual(state.progress, 0.4, accuracy: 0.001)
    }

    func test_weeklyChallengeKind_allCases_haveUniqueRawValues() {
        let rawValues = WeeklyChallengeKind.allCases.map { $0.rawValue }
        let uniqueValues = Set(rawValues)
        XCTAssertEqual(rawValues.count, uniqueValues.count, "Все rawValue должны быть уникальны")
    }

    func test_dayProgress_completedStatus_equatable() {
        XCTAssertEqual(DayProgress.completed, DayProgress.completed)
        XCTAssertNotEqual(DayProgress.locked, DayProgress.pending)
    }
}
