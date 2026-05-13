import XCTest
@testable import HappySpeech

// MARK: - PronunciationLeaderboardInteractorTests
//
// Block AA v21 — Smoke tests для PronunciationLeaderboardInteractor.
// PronunciationLeaderboardPresenter — final, spy через ViewModel (@Observable).
// 3 теста: load (empty family), load (two children sorted by accuracy), selectScope.

@MainActor
final class PronunciationLeaderboardInteractorTests: XCTestCase {

    private var sut: PronunciationLeaderboardInteractor!
    private var presenter: PronunciationLeaderboardPresenter!
    private var viewModel: PronunciationLeaderboardViewModel!
    private var mockChildRepository: MockChildRepositoryPL!
    private var mockSessionRepository: MockSessionRepositoryPL!

    override func setUp() {
        super.setUp()
        mockChildRepository = MockChildRepositoryPL()
        mockSessionRepository = MockSessionRepositoryPL()
        viewModel = PronunciationLeaderboardViewModel()
        presenter = PronunciationLeaderboardPresenter()
        presenter.viewModel = viewModel

        sut = PronunciationLeaderboardInteractor(
            childRepository: mockChildRepository,
            sessionRepository: mockSessionRepository,
            realmActor: RealmActor()
        )
        sut.presenter = presenter
    }

    override func tearDown() {
        sut = nil
        presenter = nil
        viewModel = nil
        mockChildRepository = nil
        mockSessionRepository = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_load_emptyFamily_setsStateEmpty() async {
        // Arrange: no children
        mockChildRepository.stubbedChildren = []
        // Act
        await sut.load(PronunciationLeaderboard.LoadRequest(parentId: "parent-1"))
        // Assert
        XCTAssertEqual(viewModel.state, .empty, "Без детей лидерборд должен быть пустым")
        XCTAssertTrue(viewModel.rows.isEmpty)
    }

    func test_load_twoChildren_sortedByAccuracyDescending() async {
        // Arrange
        let child1 = ChildProfileDTO(
            id: "child-1", name: "Маша", age: 6,
            targetSounds: ["Р"], parentId: "parent-1"
        )
        let child2 = ChildProfileDTO(
            id: "child-2", name: "Ваня", age: 7,
            targetSounds: ["С"], parentId: "parent-1"
        )
        mockChildRepository.stubbedChildren = [child1, child2]

        // child-1: accuracy 0.9 (9/10)
        mockSessionRepository.stubbedSessions["child-1"] = [
            makeSession(childId: "child-1", total: 10, correct: 9)
        ]
        // child-2: accuracy 0.5 (5/10)
        mockSessionRepository.stubbedSessions["child-2"] = [
            makeSession(childId: "child-2", total: 10, correct: 5)
        ]

        // Act
        await sut.load(PronunciationLeaderboard.LoadRequest(parentId: "parent-1"))

        // Assert
        XCTAssertEqual(viewModel.rows.count, 2)
        XCTAssertEqual(viewModel.rows[0].id, "child-1", "Первым должен быть child-1 (accuracy 90%)")
        XCTAssertGreaterThan(viewModel.rows[0].accuracy, viewModel.rows[1].accuracy)
    }

    func test_selectScope_changesAndReloads() async {
        // Arrange
        mockChildRepository.stubbedChildren = []
        // Act
        await sut.selectScope(PronunciationLeaderboard.SelectScopeRequest(scope: .lastWeek))
        // Assert: state должен обновиться (empty для пустого репо)
        XCTAssertEqual(viewModel.scope, .lastWeek)
    }

    // MARK: - Helpers

    private func makeSession(childId: String, total: Int, correct: Int) -> SessionDTO {
        SessionDTO(
            id: UUID().uuidString,
            childId: childId,
            date: Date(),
            templateType: "listen-and-choose",
            targetSound: "Р",
            stage: "word",
            durationSeconds: 300,
            totalAttempts: total,
            correctAttempts: correct,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
    }
}

// MARK: - MockChildRepositoryPL

final class MockChildRepositoryPL: ChildRepository, @unchecked Sendable {

    var stubbedChildren: [ChildProfileDTO] = []
    var fetchError: Error?

    func fetchAll() async throws -> [ChildProfileDTO] {
        if let error = fetchError { throw error }
        return stubbedChildren
    }

    func fetch(id: String) async throws -> ChildProfileDTO {
        guard let child = stubbedChildren.first(where: { $0.id == id }) else {
            throw AppError.unknown("ChildProfile not found: \(id)")
        }
        return child
    }

    func save(_ profile: ChildProfileDTO) async throws {}
    func delete(id: String) async throws {}
    func updateProgress(childId: String, sound: String, rate: Double) async throws {}
    func updateStreak(childId: String, streak: Int) async throws {}
}

// MARK: - MockSessionRepositoryPL

final class MockSessionRepositoryPL: SessionRepository, @unchecked Sendable {

    var stubbedSessions: [String: [SessionDTO]] = [:]

    func fetchAll(childId: String) async throws -> [SessionDTO] {
        stubbedSessions[childId] ?? []
    }

    func fetch(id: String) async throws -> SessionDTO {
        throw AppError.unknown("Session not found: \(id)")
    }

    func save(_ session: SessionDTO) async throws {}

    func fetchRecent(childId: String, limit: Int) async throws -> [SessionDTO] {
        Array((stubbedSessions[childId] ?? []).prefix(limit))
    }
}
