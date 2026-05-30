@testable import HappySpeech
import XCTest

// MARK: - MorningRoutineInteractorTests
//
// MorningRoutineInteractor is a thin VIP MVP variant (@Observable). It tracks a
// short list of morning steps; toggle(_:) flips a step's `isDone` flag (ignoring
// unknown steps) and reset() restores the all-undone initial state. The derived
// state exposes `progress` and `isCompleted`. Tests cover the seed, the toggle
// (incl. isolation), reset and the derived values across partial/full completion.
// (StepKind.title/.subtitle/.iconSystemName maps are presentational — skipped.)

@MainActor
final class MorningRoutineInteractorTests: XCTestCase {

    private typealias StepKind = MorningRoutineModels.StepKind

    private func makeSUT() -> MorningRoutineInteractor {
        MorningRoutineInteractor(childId: "child-1")
    }

    // MARK: - Init / seed

    func test_init_storesChildId() {
        let sut = MorningRoutineInteractor(childId: "c-8")
        XCTAssertEqual(sut.childId, "c-8")
    }

    func test_initialState_allStepsUndone() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
        XCTAssertEqual(Set(sut.state.steps.map(\.id)), Set(StepKind.allCases))
        XCTAssertTrue(sut.state.steps.allSatisfy { !$0.isDone })
        XCTAssertEqual(sut.state.progress, 0, accuracy: 0.0001)
        XCTAssertFalse(sut.state.isCompleted)
    }

    // MARK: - toggle

    func test_toggle_marksStepDone() {
        let sut = makeSUT()
        sut.toggle(.wash)
        XCTAssertEqual(sut.state.steps.first { $0.id == .wash }?.isDone, true)
    }

    func test_toggle_twice_restoresUndone() {
        let sut = makeSUT()
        sut.toggle(.articulation)
        sut.toggle(.articulation)
        XCTAssertEqual(sut.state.steps.first { $0.id == .articulation }?.isDone, false)
    }

    func test_toggle_onlyAffectsTarget() {
        let sut = makeSUT()
        sut.toggle(.wordPractice)
        let others = sut.state.steps.filter { $0.id != .wordPractice }
        XCTAssertTrue(others.allSatisfy { !$0.isDone })
    }

    // MARK: - reset

    func test_reset_restoresInitial() {
        let sut = makeSUT()
        StepKind.allCases.forEach { sut.toggle($0) }
        sut.reset()
        XCTAssertEqual(sut.state, .initial)
        XCTAssertTrue(sut.state.steps.allSatisfy { !$0.isDone })
    }

    // MARK: - progress / isCompleted

    func test_progress_partial() {
        let sut = makeSUT()
        sut.toggle(.wash)
        let expected = 1.0 / Double(StepKind.allCases.count)
        XCTAssertEqual(sut.state.progress, expected, accuracy: 0.0001)
        XCTAssertFalse(sut.state.isCompleted)
    }

    func test_progress_allDone_isOneAndCompleted() {
        let sut = makeSUT()
        StepKind.allCases.forEach { sut.toggle($0) }
        XCTAssertEqual(sut.state.progress, 1.0, accuracy: 0.0001)
        XCTAssertTrue(sut.state.isCompleted)
    }

    func test_isCompleted_emptySteps_isTrueVacuously() {
        var state = MorningRoutineModels.ViewState.initial
        state.steps = []
        XCTAssertTrue(state.isCompleted)
        XCTAssertEqual(state.progress, 0, accuracy: 0.0001)
    }
}
