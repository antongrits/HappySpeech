@testable import HappySpeech
import XCTest

// MARK: - HomeworkRepositoryContractTests
//
// Покрывает контракты HomeworkRepository:
//   • HomeworkRepositoryError.errorDescription — локализованные строки
//   • HomeworkExerciseItem.isDone
//   • HomeworkAssignment.isComplete / doneCount
//   • MockHomeworkRepository: updateExerciseStatus not-found,
//     fetchAssignments filter by childId, assignmentsStream initial yield
//
// Уже покрытые HomeworkSyncTests (in AssignedHomework/) — НЕ дублируются.
// Firestore-зависимостей нет — всё тестируется in-memory через actor.

final class HomeworkRepositoryContractTests: XCTestCase {

    // MARK: - Fixtures

    private func makeExercise(id: String = UUID().uuidString, repeats: Int = 3) -> HomeworkExerciseItem {
        HomeworkExerciseItem(id: id, templateRaw: "repeat-after-model", repeats: repeats)
    }

    private func makeAssignment(
        id: String = UUID().uuidString,
        childId: String = "child-1",
        exercises: [HomeworkExerciseItem]? = nil
    ) -> HomeworkAssignment {
        HomeworkAssignment(
            id: id,
            childId: childId,
            createdAt: Date(),
            dueDate: Date().addingTimeInterval(86_400),
            comment: "Тренируй звук Р",
            exercises: exercises ?? [makeExercise()]
        )
    }

    // MARK: - publish (online)

    func test_publish_online_storesAssignment() async {
        let repo = MockHomeworkRepository()
        let assignment = makeAssignment()

        let result = await repo.publish(
            assignment: assignment,
            specialistId: "spec-1",
            familyId: "family-1"
        )

        guard case .success = result else {
            return XCTFail("publish online должен вернуть .success")
        }

        let fetched = await repo.fetchAssignments(childId: assignment.childId, familyId: "family-1")
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, assignment.id)
    }

    func test_publish_online_incrementsCallCount() async {
        let repo = MockHomeworkRepository()
        _ = await repo.publish(assignment: makeAssignment(), specialistId: "s", familyId: "f")
        _ = await repo.publish(assignment: makeAssignment(), specialistId: "s", familyId: "f")
        let count = await repo.publishCallCount
        XCTAssertEqual(count, 2)
    }

    // MARK: - publish (offline)

    func test_publish_offline_doesNotStoreImmediately() async {
        let repo = MockHomeworkRepository(isOnline: false)
        let assignment = makeAssignment()

        _ = await repo.publish(assignment: assignment, specialistId: "s", familyId: "f")
        let fetched = await repo.fetchAssignments(childId: assignment.childId, familyId: "f")
        XCTAssertTrue(fetched.isEmpty, "Offline publish не должен немедленно сохранять задание")
    }

    func test_goOnlineAndFlush_deliversOutbox() async {
        let repo = MockHomeworkRepository(isOnline: false)
        let assignment = makeAssignment()

        _ = await repo.publish(assignment: assignment, specialistId: "s", familyId: "f")
        await repo.goOnlineAndFlush()

        let fetched = await repo.fetchAssignments(childId: assignment.childId, familyId: "f")
        XCTAssertEqual(fetched.count, 1, "После flush задание должно быть доступно")
    }

    // MARK: - fetchAssignments

    func test_fetchAssignments_filteredByChildId() async {
        let a1 = makeAssignment(childId: "child-A")
        let a2 = makeAssignment(childId: "child-B")
        let repo = MockHomeworkRepository(seededAssignments: [a1, a2])

        let result = await repo.fetchAssignments(childId: "child-A", familyId: "fam")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.childId, "child-A")
    }

    func test_fetchAssignments_sortedByCreatedAtDesc() async {
        let older = HomeworkAssignment(
            id: "old", childId: "child-1",
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            dueDate: Date(), comment: "", exercises: [makeExercise()]
        )
        let newer = HomeworkAssignment(
            id: "new", childId: "child-1",
            createdAt: Date(timeIntervalSince1970: 2_000_000),
            dueDate: Date(), comment: "", exercises: [makeExercise()]
        )
        let repo = MockHomeworkRepository(seededAssignments: [older, newer])
        let result = await repo.fetchAssignments(childId: "child-1", familyId: "fam")
        XCTAssertEqual(result.first?.id, "new", "Новое задание должно быть первым")
    }

    // MARK: - pendingCount

    func test_pendingCount_countsIncompleteAssignments() async {
        let incomplete = makeAssignment(exercises: [makeExercise(repeats: 3)])
        let completeEx = HomeworkExerciseItem(
            id: "done", templateRaw: "listen-and-choose", repeats: 2, completedRepeats: 2
        )
        let complete = makeAssignment(id: "a2", exercises: [completeEx])

        let repo = MockHomeworkRepository(seededAssignments: [incomplete, complete])
        let count = await repo.pendingCount(childId: incomplete.childId, familyId: "fam")
        XCTAssertEqual(count, 1)
    }

    // MARK: - updateExerciseStatus

    func test_updateExerciseStatus_updatesCompletedRepeats() async {
        let exercise = makeExercise(id: "ex-1", repeats: 5)
        let assignment = makeAssignment(id: "assign-1", exercises: [exercise])
        let repo = MockHomeworkRepository(seededAssignments: [assignment])

        let result = await repo.updateExerciseStatus(
            assignmentId: "assign-1",
            exerciseId: "ex-1",
            completedRepeats: 4
        )
        guard case .success = result else {
            return XCTFail("updateExerciseStatus должен вернуть .success")
        }
        let updateCount = await repo.updateStatusCallCount
        XCTAssertEqual(updateCount, 1)

        let updated = await repo.fetchAssignments(childId: assignment.childId, familyId: "fam")
        XCTAssertEqual(updated.first?.exercises.first?.completedRepeats, 4)
    }

    func test_updateExerciseStatus_notFound_returnsFailure() async {
        let repo = MockHomeworkRepository()
        let result = await repo.updateExerciseStatus(
            assignmentId: "nonexistent",
            exerciseId: "ex-999",
            completedRepeats: 1
        )
        guard case .failure(let error) = result else {
            return XCTFail("Ожидалась ошибка .failure")
        }
        XCTAssertEqual(error, .assignmentNotFound)
    }

    // MARK: - injectAssignment (real-time helper)

    func test_injectAssignment_addsToStorage() async {
        let repo = MockHomeworkRepository()
        let assignment = makeAssignment(childId: "child-rt")
        await repo.injectAssignment(assignment, familyId: "fam-rt")

        let fetched = await repo.fetchAssignments(childId: "child-rt", familyId: "fam-rt")
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, assignment.id)
    }

    // MARK: - assignmentsStream

    func test_assignmentsStream_yieldsInitialState() async {
        let assignment = makeAssignment(childId: "stream-child")
        let repo = MockHomeworkRepository(seededAssignments: [assignment])

        var received: [HomeworkAssignment] = []
        let stream = repo.assignmentsStream(childId: "stream-child", familyId: "fam")

        // Ждём первого yield (initial snapshot).
        for await batch in stream {
            received = batch
            break
        }
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received.first?.id, assignment.id)
    }

    // MARK: - HomeworkRepositoryError

    func test_error_notAuthenticated_hasNonEmptyDescription() {
        let error = HomeworkRepositoryError.notAuthenticated
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func test_error_writeFailedOffline_hasNonEmptyDescription() {
        let error = HomeworkRepositoryError.writeFailedOffline
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func test_error_assignmentNotFound_hasNonEmptyDescription() {
        let error = HomeworkRepositoryError.assignmentNotFound
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func test_error_backendUnavailable_hasNonEmptyDescription() {
        let error = HomeworkRepositoryError.backendUnavailable("503 от сервера")
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func test_error_equatable_sameCase() {
        XCTAssertEqual(HomeworkRepositoryError.notAuthenticated, .notAuthenticated)
        XCTAssertEqual(HomeworkRepositoryError.assignmentNotFound, .assignmentNotFound)
    }

    func test_error_equatable_differentCases() {
        XCTAssertNotEqual(HomeworkRepositoryError.notAuthenticated, .assignmentNotFound)
    }
}
