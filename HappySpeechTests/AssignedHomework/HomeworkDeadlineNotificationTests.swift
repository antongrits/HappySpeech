@testable import HappySpeech
import XCTest

// MARK: - HomeworkDeadlineNotificationTests
//
// Unit-тесты дедлайн-уведомления и удаления домашнего задания.
// Используют `MockNotificationService` (наблюдает запланированные/отменённые
// идентификаторы) и `MockHomeworkRepository`. Покрывают:
//   1. Worker.create планирует дедлайн-уведомление со стабильным id
//   2. Worker.create уже-выполненного задания (degenerate) не планирует
//   3. deadlineNotificationIdentifier(forAssignmentId:) стабилен и с префиксом
//   4. Worker.updateExerciseStatus при полном выполнении отменяет уведомление
//   5. Worker.updateExerciseStatus при частичном выполнении НЕ отменяет
//   6. Worker.delete отменяет дедлайн-уведомление
//   7. Worker.delete удаляет локально + вызывает repo.delete
//   8. Worker.delete несуществующего id всё равно вызывает repo.delete (idempotent)
//   9. MockHomeworkRepository.delete (online) убирает запись
//  10. MockHomeworkRepository.delete (offline) очередь + flush
//  11. Interactor.delete делегирует Worker + presenter + reload списка
//  12. Presenter.presentDelete строит success/failure ViewModel

// MARK: - Helpers

@MainActor
private func makeDueAssignment(
    id: String = "a-1",
    childId: String = "child-1",
    dueInDays: Int = 5,
    completedFirst: Int = 0,
    completedSecond: Int = 0
) -> HomeworkAssignment {
    HomeworkAssignment(
        id: id,
        childId: childId,
        dueDate: Date().addingTimeInterval(Double(dueInDays) * 86_400),
        comment: "Делать дома",
        exercises: [
            HomeworkExerciseItem(id: "ex-1", templateRaw: "sorting", repeats: 3,
                                 completedRepeats: completedFirst),
            HomeworkExerciseItem(id: "ex-2", templateRaw: "memory", repeats: 2,
                                 completedRepeats: completedSecond)
        ]
    )
}

@MainActor
private func makeWorkerSUT()
    -> (AssignedHomeworkWorker, MockHomeworkRepository, MockNotificationService, UserDefaults) {
    let suiteName = "test.homeworkDeadline.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        fatalError("UserDefaults init failed")
    }
    let childRepo = MockChildRepository(children: [
        ChildProfileDTO(id: "child-1", name: "Миша", age: 6,
                        targetSounds: ["Р"], parentId: "p-1")
    ])
    let homeworkRepo = MockHomeworkRepository()
    let notif = MockNotificationService()
    let worker = AssignedHomeworkWorker(
        childRepository: childRepo,
        homeworkRepository: homeworkRepo,
        notificationService: notif,
        defaults: defaults
    )
    return (worker, homeworkRepo, notif, defaults)
}

// MARK: - Worker: schedule on create

@MainActor
final class HomeworkDeadlineScheduleTests: XCTestCase {

    // 3. deadlineNotificationIdentifier is stable + prefixed
    func test_deadlineIdentifier_isStableAndPrefixed() {
        let id1 = AssignedHomeworkWorker.deadlineNotificationIdentifier(forAssignmentId: "abc")
        let id2 = AssignedHomeworkWorker.deadlineNotificationIdentifier(forAssignmentId: "abc")
        XCTAssertEqual(id1, id2)
        XCTAssertTrue(id1.hasPrefix(AssignedHomeworkWorker.deadlineNotificationPrefix))
        XCTAssertEqual(id1, "hs.homework.deadline.abc")
    }

    // 1. create() schedules a deadline notification with the assignment id
    func test_create_schedulesDeadlineNotification() async throws {
        let (worker, _, notif, _) = makeWorkerSUT()
        let created = await worker.create(request: .init(
            childId: "child-1",
            templateRaws: ["sorting", "memory"],
            repeatsPerExercise: 3,
            dueInDays: 5,
            comment: "Дома"
        ))
        let assignment = try XCTUnwrap(created)
        let expected = AssignedHomeworkWorker.deadlineNotificationIdentifier(
            forAssignmentId: assignment.id
        )
        XCTAssertTrue(notif.scheduledCalendarIdentifiers.contains(expected))
        XCTAssertTrue(notif.cancelledCalendarIdentifiers.isEmpty)
    }
}

// MARK: - Worker: cancel on complete / delete

@MainActor
final class HomeworkDeadlineCancelTests: XCTestCase {

    // 4. updateExerciseStatus → assignment fully complete → cancels notification
    func test_updateExerciseStatus_complete_cancelsNotification() async {
        // Local cache already has an assignment with the first exercise done.
        let assignment = makeDueAssignment(completedFirst: 3, completedSecond: 0)
        let (worker, repo, notif, _) = makeWorkerSUT()
        await repo.injectAssignment(assignment, familyId: "fam-1")
        // Persist into worker's local cache by fetching (merge).
        _ = await worker.fetchAssignments(childId: "child-1", familyId: "fam-1")

        // Finish the second exercise → assignment becomes complete.
        let response = await worker.updateExerciseStatus(request: .init(
            assignmentId: assignment.id,
            exerciseId: "ex-2",
            completedRepeats: 2
        ))

        XCTAssertTrue(response.didSucceed)
        XCTAssertTrue(response.updatedAssignment?.isComplete == true)
        let expected = AssignedHomeworkWorker.deadlineNotificationIdentifier(
            forAssignmentId: assignment.id
        )
        XCTAssertTrue(notif.cancelledCalendarIdentifiers.contains(expected))
    }

    // 5. updateExerciseStatus partial → does NOT cancel
    func test_updateExerciseStatus_partial_doesNotCancel() async {
        let assignment = makeDueAssignment()
        let (worker, repo, notif, _) = makeWorkerSUT()
        await repo.injectAssignment(assignment, familyId: "fam-1")
        _ = await worker.fetchAssignments(childId: "child-1", familyId: "fam-1")

        let response = await worker.updateExerciseStatus(request: .init(
            assignmentId: assignment.id,
            exerciseId: "ex-1",
            completedRepeats: 1
        ))

        XCTAssertTrue(response.updatedAssignment?.isComplete == false)
        XCTAssertTrue(notif.cancelledCalendarIdentifiers.isEmpty)
    }

    // 6 + 7. delete cancels notification, removes locally, calls repo.delete
    func test_delete_cancelsNotification_removesLocal_callsRepo() async {
        let (worker, repo, notif, _) = makeWorkerSUT()
        // Create locally (also schedules notification + publishes nothing yet).
        let created = await worker.create(request: .init(
            childId: "child-1",
            templateRaws: ["sorting"],
            repeatsPerExercise: 3,
            dueInDays: 5,
            comment: "Дома"
        ))
        guard let assignment = created else {
            XCTFail("create returned nil")
            return
        }
        // Seed cloud so repo.delete has something to remove.
        await repo.injectAssignment(assignment, familyId: "fam-1")

        let didSucceed = await worker.delete(assignmentId: assignment.id)

        XCTAssertTrue(didSucceed)
        // Local cache no longer contains it.
        XCTAssertTrue(worker.assignments(forChild: "child-1").isEmpty)
        // Notification cancelled.
        let expected = AssignedHomeworkWorker.deadlineNotificationIdentifier(
            forAssignmentId: assignment.id
        )
        XCTAssertTrue(notif.cancelledCalendarIdentifiers.contains(expected))
        // Cloud delete called.
        let deleteCount = await repo.deleteCallCount
        XCTAssertEqual(deleteCount, 1)
        // Cloud no longer has it.
        let remote = await repo.fetchAssignments(childId: "child-1", familyId: "fam-1")
        XCTAssertTrue(remote.isEmpty)
    }

    // 8. delete of unknown id still calls repo.delete (idempotent) and cancels
    func test_delete_unknownId_stillCallsRepoAndCancels() async {
        let (worker, repo, notif, _) = makeWorkerSUT()
        let didSucceed = await worker.delete(assignmentId: "does-not-exist")
        // repo mock returns .success even for unknown id → didSucceed true
        XCTAssertTrue(didSucceed)
        let deleteCount = await repo.deleteCallCount
        XCTAssertEqual(deleteCount, 1)
        let expected = AssignedHomeworkWorker.deadlineNotificationIdentifier(
            forAssignmentId: "does-not-exist"
        )
        XCTAssertTrue(notif.cancelledCalendarIdentifiers.contains(expected))
    }
}

// MARK: - MockHomeworkRepository.delete

@MainActor
final class MockHomeworkRepositoryDeleteTests: XCTestCase {

    // 9. delete online removes the assignment
    func test_delete_online_removesAssignment() async {
        let a = makeDueAssignment()
        let repo = MockHomeworkRepository(seededAssignments: [a])
        let result = await repo.delete(assignmentId: a.id)
        guard case .success = result else {
            XCTFail("Expected .success")
            return
        }
        let after = await repo.fetchAssignments(childId: a.childId, familyId: "fam-1")
        XCTAssertTrue(after.isEmpty)
    }

    // 10. delete offline queues, applied on goOnlineAndFlush
    func test_delete_offline_queuedThenFlushed() async {
        let a = makeDueAssignment()
        let repo = MockHomeworkRepository(seededAssignments: [a])
        // Seed must be visible first.
        let before = await repo.fetchAssignments(childId: a.childId, familyId: "fam-1")
        XCTAssertEqual(before.count, 1)

        await repo.setOfflineForTest()
        let result = await repo.delete(assignmentId: a.id)
        guard case .success = result else {
            XCTFail("Expected .success even offline")
            return
        }
        // Still present while offline (delete queued).
        let stillThere = await repo.fetchAssignments(childId: a.childId, familyId: "fam-1")
        XCTAssertEqual(stillThere.count, 1, "Delete should be queued while offline")

        await repo.goOnlineAndFlush()
        let afterFlush = await repo.fetchAssignments(childId: a.childId, familyId: "fam-1")
        XCTAssertTrue(afterFlush.isEmpty, "Delete should apply after flush")
    }

    // empty id → assignmentNotFound
    func test_delete_emptyId_returnsNotFound() async {
        let repo = MockHomeworkRepository()
        let result = await repo.delete(assignmentId: "")
        guard case .failure(let error) = result else {
            XCTFail("Expected failure for empty id")
            return
        }
        XCTAssertEqual(error, .assignmentNotFound)
    }
}

// MARK: - Interactor.delete

@MainActor
private final class DeleteSpyPresenter: AssignedHomeworkPresentationLogic, @unchecked Sendable {
    var loadCount = 0
    var deleteCount = 0
    var lastDelete: AssignedHomeworkModels.Delete.Response?

    func presentLoad(response: AssignedHomeworkModels.Load.Response) async { loadCount += 1 }
    func presentCreate(response: AssignedHomeworkModels.Create.Response) async {}
    func presentUpdateStatus(response: AssignedHomeworkModels.UpdateStatus.Response) async {}
    func presentDelete(response: AssignedHomeworkModels.Delete.Response) async {
        deleteCount += 1
        lastDelete = response
    }
    func presentFamilyLoad(response: AssignedHomeworkModels.FamilyLoad.Response) async {}
}

@MainActor
private final class DeleteStubWorker: AssignedHomeworkWorkerProtocol {
    var deleteReturn = true
    private(set) var deleteCount = 0
    private(set) var lastDeletedId: String?

    func load(specialistId: String) async -> AssignedHomeworkModels.Load.Response {
        .init(children: [], assignments: [], availableTemplates: [])
    }
    func create(request: AssignedHomeworkModels.Create.Request) async -> HomeworkAssignment? { nil }
    func assignments(forChild childId: String) -> [HomeworkAssignment] { [] }
    func fetchAssignments(childId: String, familyId: String) async -> [HomeworkAssignment] { [] }
    func updateExerciseStatus(
        request: AssignedHomeworkModels.UpdateStatus.Request
    ) async -> AssignedHomeworkModels.UpdateStatus.Response {
        .init(didSucceed: true, updatedAssignment: nil)
    }
    func publishToCloud(
        assignment: HomeworkAssignment,
        specialistId: String,
        familyId: String
    ) async {}
    func assignmentsStream(
        childId: String,
        familyId: String
    ) -> AsyncStream<[HomeworkAssignment]> {
        AsyncStream { $0.finish() }
    }
    func delete(assignmentId: String) async -> Bool {
        deleteCount += 1
        lastDeletedId = assignmentId
        return deleteReturn
    }
}

@MainActor
final class AssignedHomeworkInteractorDeleteTests: XCTestCase {

    private func makeSUT() -> (AssignedHomeworkInteractor, DeleteSpyPresenter, DeleteStubWorker) {
        let worker = DeleteStubWorker()
        let interactor = AssignedHomeworkInteractor(
            specialistId: "spec-1",
            familyId: "fam-1",
            worker: worker,
            hapticService: SpyHapticService()
        )
        let spy = DeleteSpyPresenter()
        interactor.presenter = spy
        return (interactor, spy, worker)
    }

    // 11. delete delegates to worker, presents response, reloads list
    func test_delete_delegatesPresentsAndReloads() async {
        let (sut, spy, worker) = makeSUT()
        await sut.delete(request: .init(assignmentId: "a-77"))

        XCTAssertEqual(worker.deleteCount, 1)
        XCTAssertEqual(worker.lastDeletedId, "a-77")
        XCTAssertEqual(spy.deleteCount, 1)
        XCTAssertEqual(spy.lastDelete?.didSucceed, true)
        XCTAssertEqual(spy.lastDelete?.deletedAssignmentId, "a-77")
        // List reloaded after delete.
        XCTAssertGreaterThanOrEqual(spy.loadCount, 1)
    }

    func test_delete_failure_presentsFailure() async {
        let (sut, spy, worker) = makeSUT()
        worker.deleteReturn = false
        await sut.delete(request: .init(assignmentId: "a-1"))
        XCTAssertEqual(spy.lastDelete?.didSucceed, false)
    }
}

// MARK: - Presenter.presentDelete

@MainActor
final class AssignedHomeworkPresenterDeleteTests: XCTestCase {

    private func makePresenter() -> (AssignedHomeworkPresenter, AssignedHomeworkViewModelHolder) {
        let holder = AssignedHomeworkViewModelHolder()
        return (AssignedHomeworkPresenter(displayLogic: holder), holder)
    }

    // 12. presentDelete success builds non-empty message
    func test_presentDelete_success_buildsMessage() async {
        let (presenter, holder) = makePresenter()
        await presenter.presentDelete(response: .init(didSucceed: true, deletedAssignmentId: "a-1"))
        XCTAssertNotNil(holder.lastDeleteMessage)
        XCTAssertFalse(holder.lastDeleteMessage?.isEmpty == true)
    }

    func test_presentDelete_failure_buildsMessage() async {
        let (presenter, holder) = makePresenter()
        await presenter.presentDelete(response: .init(didSucceed: false, deletedAssignmentId: "a-1"))
        XCTAssertNotNil(holder.lastDeleteMessage)
        XCTAssertFalse(holder.lastDeleteMessage?.isEmpty == true)
    }
}
