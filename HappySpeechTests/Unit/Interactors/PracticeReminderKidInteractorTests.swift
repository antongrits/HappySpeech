@testable import HappySpeech
import XCTest

// MARK: - PracticeReminderKidInteractorTests
//
// PracticeReminderKidInteractor is a thin VIP MVP variant (@Observable). The
// only behaviour is snooze() which marks the reminder dismissed.

@MainActor
final class PracticeReminderKidInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> PracticeReminderKidInteractor {
        PracticeReminderKidInteractor(childId: childId)
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-9")
        XCTAssertEqual(sut.childId, "kid-9")
    }

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_notDismissed() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.isDismissed)
    }

    func test_initialState_carriesEstimatesAndStreak() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.estimatedMinutes, 5)
        XCTAssertEqual(sut.state.streakDays, 4)
    }

    // MARK: - snooze

    func test_snooze_setsDismissed() {
        let sut = makeSUT()
        sut.snooze()
        XCTAssertTrue(sut.state.isDismissed)
    }

    func test_snooze_isIdempotent() {
        let sut = makeSUT()
        sut.snooze()
        sut.snooze()
        XCTAssertTrue(sut.state.isDismissed)
    }

    func test_snooze_doesNotChangeEstimatesOrStreak() {
        let sut = makeSUT()
        sut.snooze()
        XCTAssertEqual(sut.state.estimatedMinutes, 5)
        XCTAssertEqual(sut.state.streakDays, 4)
    }
}
