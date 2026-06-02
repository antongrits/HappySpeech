@testable import HappySpeech
import XCTest

// MARK: - MorningRoutineInteractorTests
//
// Утренняя рутина: набор шагов; toggle(_:) переключает isDone и персистит
// состояние дня в MorningRoutineStore (per child+day). Тесты используют
// изолированный UserDefaults и проверяют seed, toggle, изоляцию, reset, derived
// (progress/isCompleted) и персистентность между экземплярами.

@MainActor
final class MorningRoutineInteractorTests: XCTestCase {

    private typealias StepKind = MorningRoutineModels.StepKind

    private var defaults: UserDefaults!
    private let suiteName = "test.morningRoutine"

    override func setUp() async throws {
        try await super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        try await super.tearDown()
    }

    private func makeSUT(childId: String = "child-1") -> MorningRoutineInteractor {
        let sut = MorningRoutineInteractor(childId: childId, defaults: defaults)
        sut.load()
        return sut
    }

    // MARK: - Init / load

    func test_init_storesChildId() {
        let sut = MorningRoutineInteractor(childId: "c-8", defaults: defaults)
        XCTAssertEqual(sut.childId, "c-8")
    }

    func test_load_allStepsUndone() {
        let sut = makeSUT()
        XCTAssertTrue(sut.state.isLoaded)
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

    // MARK: - Persistence

    func test_persistence_survivesNewInstance() {
        let sut1 = makeSUT(childId: "kid-p")
        sut1.toggle(.wash)
        sut1.toggle(.smile)
        // Новый экземпляр того же ребёнка с тем же UserDefaults восстанавливает день.
        let sut2 = MorningRoutineInteractor(childId: "kid-p", defaults: defaults)
        sut2.load()
        XCTAssertEqual(sut2.state.doneSet, [.wash, .smile])
    }

    // MARK: - reset

    func test_reset_clearsAll() {
        let sut = makeSUT()
        StepKind.allCases.forEach { sut.toggle($0) }
        sut.reset()
        XCTAssertTrue(sut.state.steps.allSatisfy { !$0.isDone })
        XCTAssertTrue(sut.state.doneSet.isEmpty)
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
}
