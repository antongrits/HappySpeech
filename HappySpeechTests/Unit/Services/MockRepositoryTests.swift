import XCTest
@testable import HappySpeech

// MARK: - MockChildRepositoryTests

final class MockChildRepositoryTests: XCTestCase {

    func testFetchAllReturnsChildren() async throws {
        let repo = MockChildRepository(children: [.preview])
        let children = try await repo.fetchAll()
        XCTAssertEqual(children.count, 1)
        XCTAssertEqual(children.first?.name, "Миша")
    }

    func testSaveAddsChild() async throws {
        let repo = MockChildRepository(children: [])
        let profile = ChildProfileDTO(
            id: "new-1",
            name: "Аня",
            age: 5,
            targetSounds: ["С"],
            parentId: "parent-1"
        )
        try await repo.save(profile)
        let children = try await repo.fetchAll()
        XCTAssertEqual(children.count, 1)
        XCTAssertEqual(children.first?.name, "Аня")
    }

    func testDeleteRemovesChild() async throws {
        let repo = MockChildRepository(children: [.preview])
        try await repo.delete(id: ChildProfileDTO.preview.id)
        let children = try await repo.fetchAll()
        XCTAssertTrue(children.isEmpty)
    }

    func testFetchNonExistentThrows() async throws {
        let repo = MockChildRepository(children: [])
        do {
            _ = try await repo.fetch(id: "nonexistent")
            XCTFail("Должна быть выброшена ошибка")
        } catch AppError.entityNotFound {
            // Expected
        }
    }
}

// MARK: - MockSessionRepositoryTests

final class MockSessionRepositoryTests: XCTestCase {

    func testSaveAndFetch() async throws {
        let repo = MockSessionRepository(sessions: [])
        try await repo.save(.preview)
        let sessions = try await repo.fetchAll(childId: "preview-child-1")
        XCTAssertEqual(sessions.count, 1)
    }

    func testSuccessRateCalculation() {
        let session = SessionDTO.preview
        XCTAssertEqual(session.successRate, 0.75, accuracy: 0.01)
    }
}
