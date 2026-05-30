@testable import HappySpeech
import XCTest

// MARK: - GoalTrackerKidInteractorTests
//
// GoalTrackerKidInteractor is a thin VIP MVP variant (@Observable, no separate
// Presenter/DisplayLogic). Tests verify bump() clamping, reset() and the
// computed progress on Goal / ViewState.

@MainActor
final class GoalTrackerKidInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> GoalTrackerKidInteractor {
        GoalTrackerKidInteractor(childId: childId)
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-42")
        XCTAssertEqual(sut.childId, "kid-42")
    }

    func test_initialState_matchesInitialViewState() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_hasAllGoalKinds() {
        let sut = makeSUT()
        let kinds = Set(sut.state.goals.map(\.id))
        XCTAssertEqual(kinds, Set(GoalTrackerKidModels.GoalKind.allCases))
    }

    // MARK: - bump

    func test_bump_incrementsCurrentByOne() {
        let sut = makeSUT()
        let before = currentValue(sut, for: .minutesToday)
        sut.bump(.minutesToday)
        XCTAssertEqual(currentValue(sut, for: .minutesToday), before + 1)
    }

    func test_bump_doesNotAffectOtherGoals() {
        let sut = makeSUT()
        let otherBefore = currentValue(sut, for: .streakDays)
        sut.bump(.newSounds)
        XCTAssertEqual(currentValue(sut, for: .streakDays), otherBefore)
    }

    func test_bump_stopsAtTarget() {
        let sut = makeSUT()
        // newSounds initial = 2, target = 3 → one bump reaches target, further bumps no-op.
        sut.bump(.newSounds) // 3 == target
        sut.bump(.newSounds) // should not exceed target
        sut.bump(.newSounds)
        let goal = goal(sut, for: .newSounds)
        XCTAssertEqual(goal.current, goal.target)
        XCTAssertTrue(goal.isReached)
    }

    func test_bump_reachingTarget_setsProgressToOne() {
        let sut = makeSUT()
        // minutesToday initial = 6, target = 10 → bump 4 times.
        for _ in 0..<4 { sut.bump(.minutesToday) }
        XCTAssertEqual(goal(sut, for: .minutesToday).progress, 1.0, accuracy: 0.0001)
    }

    // MARK: - progress computations

    func test_goalProgress_isFractionOfTarget() {
        let sut = makeSUT()
        // minutesToday = 6/10 = 0.6
        XCTAssertEqual(goal(sut, for: .minutesToday).progress, 0.6, accuracy: 0.0001)
    }

    func test_overallProgress_isAverageOfGoalProgress() {
        let sut = makeSUT()
        let expected = sut.state.goals.map(\.progress).reduce(0, +) / Double(sut.state.goals.count)
        XCTAssertEqual(sut.state.overallProgress, expected, accuracy: 0.0001)
    }

    func test_goalProgress_zeroTarget_isZero() {
        let goal = GoalTrackerKidModels.Goal(id: .streakDays, current: 5, target: 0)
        XCTAssertEqual(goal.progress, 0)
    }

    func test_overallProgress_emptyGoals_isZero() {
        let state = GoalTrackerKidModels.ViewState(goals: [])
        XCTAssertEqual(state.overallProgress, 0)
    }

    // MARK: - reset

    func test_reset_restoresInitialState() {
        let sut = makeSUT()
        sut.bump(.minutesToday)
        sut.bump(.newSounds)
        sut.reset()
        XCTAssertEqual(sut.state, .initial)
    }

    // MARK: - Helpers

    private func goal(_ sut: GoalTrackerKidInteractor, for kind: GoalTrackerKidModels.GoalKind) -> GoalTrackerKidModels.Goal {
        sut.state.goals.first { $0.id == kind }!
    }

    private func currentValue(_ sut: GoalTrackerKidInteractor, for kind: GoalTrackerKidModels.GoalKind) -> Int {
        goal(sut, for: kind).current
    }
}
