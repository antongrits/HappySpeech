@testable import HappySpeech
import XCTest

// MARK: - SyncServiceExtTests
//
// Block V v18 — дополнительные тесты MockSyncService (6 тестов).
// Тестируется контрактное поведение через MockSyncService.

final class SyncServiceExtTests: XCTestCase {

    private func makeSUT() -> MockSyncService {
        MockSyncService()
    }

    // MARK: - pendingCount

    func test_pendingCount_initiallyZero() async {
        let sut = makeSUT()
        let count = await sut.pendingCount()
        XCTAssertEqual(count, 0)
    }

    func test_pendingCount_incrementsAfterEnqueue() async throws {
        let sut = makeSUT()
        let op = SyncOperation(
            entityType: "Session",
            entityId: UUID().uuidString,
            operation: "create",
            payload: "{}"
        )
        try await sut.enqueue(operation: op)
        let count = await sut.pendingCount()
        XCTAssertEqual(count, 1)
    }

    func test_pendingCount_multipleEnqueues_accumulates() async throws {
        let sut = makeSUT()
        let op = SyncOperation(
            entityType: "Session",
            entityId: UUID().uuidString,
            operation: "update",
            payload: "{}"
        )
        try await sut.enqueue(operation: op)
        try await sut.enqueue(operation: op)
        try await sut.enqueue(operation: op)
        let count = await sut.pendingCount()
        XCTAssertEqual(count, 3)
    }

    // MARK: - isSyncing

    func test_isSyncing_initiallyFalse() async {
        let sut = makeSUT()
        let syncing = await sut.isSyncing()
        XCTAssertFalse(syncing)
    }

    // MARK: - drainQueue

    func test_drainQueue_doesNotThrow() async {
        let sut = makeSUT()
        await XCTAssertNoThrowAsync { try await sut.drainQueue() }
    }

    // MARK: - SyncState equality

    func test_syncState_idle_equalsIdle() {
        XCTAssertEqual(SyncState.idle, SyncState.idle)
    }

    func test_syncState_completed_withSameCount_isEqual() {
        XCTAssertEqual(SyncState.completed(itemsSynced: 5), SyncState.completed(itemsSynced: 5))
    }

    func test_syncState_failed_withSameMessage_isEqual() {
        let msg = "Сеть недоступна"
        XCTAssertEqual(SyncState.failed(message: msg), SyncState.failed(message: msg))
    }
}

private func XCTAssertNoThrowAsync(
    _ expression: () async throws -> Void,
    file: StaticString = #file,
    line: UInt = #line
) async {
    do {
        try await expression()
    } catch {
        XCTFail("Unexpected throw: \(error)", file: file, line: line)
    }
}
