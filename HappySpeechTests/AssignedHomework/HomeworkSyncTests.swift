@testable import HappySpeech
import XCTest

// MARK: - HomeworkSyncTests
//
// Unit-тесты реального Firestore-синка домашних заданий.
// Используют `MockHomeworkRepository` (actor) и `StubAssignedHomeworkWorker` —
// никаких сетевых вызовов. Покрывают:
//   1. Публикация задания попадает в MockHomeworkRepository
//   2. Чтение из MockHomeworkRepository (familyLoad flow)
//   3. Обновление статуса упражнения — локально и в репозитории
//   4. Offline-режим: задание ставится в очередь, доставляется при goOnline
//   5. Real-time поток: новое задание появляется в AssignmentStream
//   6. pendingCount корректен до и после обновления статуса
//   7. Interactor.create() вызывает publishToCloud с правильным specialistId
//   8. Interactor.updateExerciseStatus() делегирует в worker
//   9. Interactor.loadForFamily() фетчит из worker + вызывает presenter
//  10. Presenter.presentFamilyLoad() строит корректную ViewModel
//  11. Presenter.presentUpdateStatus() строит progressLabel
//  12. Worker.create() с invalid request возвращает nil, не пишет в репозиторий

// MARK: - Helpers

@MainActor
private func makeAssignment(
    id: String = UUID().uuidString,
    childId: String = "child-1"
) -> HomeworkAssignment {
    HomeworkAssignment(
        id: id,
        childId: childId,
        dueDate: Date().addingTimeInterval(3 * 86_400),
        comment: "Делать дома",
        exercises: [
            HomeworkExerciseItem(id: "ex-1", templateRaw: "sorting", repeats: 3),
            HomeworkExerciseItem(id: "ex-2", templateRaw: "memory", repeats: 2)
        ]
    )
}

// MARK: - Test 1-4, 6: MockHomeworkRepository directly

@MainActor
final class MockHomeworkRepositoryTests: XCTestCase {

    // 1. publish → stored and returned by fetchAssignments
    func test_publish_storesAssignment() async {
        let repo = MockHomeworkRepository()
        let a = makeAssignment()
        let result = await repo.publish(assignment: a, specialistId: "spec-1", familyId: "fam-1")
        guard case .success = result else {
            XCTFail("Expected .success")
            return
        }
        let fetched = await repo.fetchAssignments(childId: a.childId, familyId: "fam-1")
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, a.id)
    }

    // 2. fetchAssignments returns seeded
    func test_fetch_returnsSeeded() async {
        let a = makeAssignment()
        let repo = MockHomeworkRepository(seededAssignments: [a])
        let fetched = await repo.fetchAssignments(childId: a.childId, familyId: "fam-1")
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, a.id)
    }

    // 3. updateExerciseStatus patches completedRepeats
    func test_updateExerciseStatus_patchesRepeats() async {
        let a = makeAssignment()
        let repo = MockHomeworkRepository(seededAssignments: [a])
        let result = await repo.updateExerciseStatus(
            assignmentId: a.id,
            exerciseId: "ex-1",
            completedRepeats: 3
        )
        guard case .success = result else {
            XCTFail("Expected .success")
            return
        }
        let fetched = await repo.fetchAssignments(childId: a.childId, familyId: "fam-1")
        let updated = fetched.first?.exercises.first(where: { $0.id == "ex-1" })
        XCTAssertEqual(updated?.completedRepeats, 3)
        XCTAssertTrue(updated?.isDone == true)
    }

    // 4. offline: assignment queued, then delivered after goOnlineAndFlush
    func test_offline_queue_flushOnGoOnline() async {
        let a = makeAssignment()
        let repo = MockHomeworkRepository(isOnline: false)
        let result = await repo.publish(assignment: a, specialistId: "spec-1", familyId: "fam-1")
        guard case .success = result else {
            XCTFail("Expected .success even offline")
            return
        }
        // Before flush — not visible yet (isOnline=false, stored in outbox)
        let before = await repo.fetchAssignments(childId: a.childId, familyId: "fam-1")
        XCTAssertTrue(before.isEmpty, "Should not be in store while offline")

        await repo.goOnlineAndFlush()
        let after = await repo.fetchAssignments(childId: a.childId, familyId: "fam-1")
        XCTAssertEqual(after.count, 1, "Should appear after flush")
    }

    // 6. pendingCount correct
    func test_pendingCount_correctBeforeAndAfterComplete() async {
        let a = makeAssignment()
        let repo = MockHomeworkRepository(seededAssignments: [a])
        let before = await repo.pendingCount(childId: a.childId, familyId: "fam-1")
        XCTAssertEqual(before, 1)

        _ = await repo.updateExerciseStatus(
            assignmentId: a.id, exerciseId: "ex-1", completedRepeats: 3
        )
        _ = await repo.updateExerciseStatus(
            assignmentId: a.id, exerciseId: "ex-2", completedRepeats: 2
        )
        let after = await repo.pendingCount(childId: a.childId, familyId: "fam-1")
        XCTAssertEqual(after, 0)
    }
}

// MARK: - Tests 5: Real-time stream yields updates

@MainActor
final class HomeworkStreamTests: XCTestCase {

    // 5. Real-time stream: yields new assignment after injectAssignment
    func test_assignmentsStream_yieldsAfterInject() async {
        let a = makeAssignment()
        let repo = MockHomeworkRepository()
        var received: [[HomeworkAssignment]] = []

        let streamTask = Task {
            for await snapshot in repo.assignmentsStream(childId: a.childId, familyId: "fam-1") {
                received.append(snapshot)
                if snapshot.contains(where: { $0.id == a.id }) { break }
            }
        }

        // Yield initial empty snapshot, then inject assignment.
        try? await Task.sleep(for: .milliseconds(50))
        await repo.injectAssignment(a, familyId: "fam-1")
        await streamTask.value

        XCTAssertTrue(received.contains(where: { $0.contains { $0.id == a.id } }))
    }
}

// MARK: - Test 7, 8, 9: Interactor wiring via spies

// Spy presenter for interactor tests
@MainActor
private final class SpyAssignedHomeworkPresenterExt:
    AssignedHomeworkPresentationLogic,
    @unchecked Sendable
{
    var loadCount = 0
    var createCount = 0
    var updateStatusCount = 0
    var familyLoadCount = 0
    var lastCreate: AssignedHomeworkModels.Create.Response?
    var lastUpdateStatus: AssignedHomeworkModels.UpdateStatus.Response?
    var lastFamilyLoad: AssignedHomeworkModels.FamilyLoad.Response?

    func presentLoad(response: AssignedHomeworkModels.Load.Response) async {
        loadCount += 1
    }
    func presentCreate(response: AssignedHomeworkModels.Create.Response) async {
        createCount += 1
        lastCreate = response
    }
    func presentUpdateStatus(response: AssignedHomeworkModels.UpdateStatus.Response) async {
        updateStatusCount += 1
        lastUpdateStatus = response
    }
    func presentFamilyLoad(response: AssignedHomeworkModels.FamilyLoad.Response) async {
        familyLoadCount += 1
        lastFamilyLoad = response
    }
}

// Configurable worker stub with tracking
@MainActor
private final class SpyAssignedHomeworkWorkerExt: AssignedHomeworkWorkerProtocol {

    var createResult: HomeworkAssignment?
    var publishToCloudCallCount = 0
    var lastPublishedSpecialistId: String?
    var lastPublishedFamilyId: String?
    var updateStatusResult = AssignedHomeworkModels.UpdateStatus.Response(
        didSucceed: true, updatedAssignment: nil
    )
    var fetchResult: [HomeworkAssignment] = []

    private let loadBase: AssignedHomeworkModels.Load.Response

    init(loadResponse: AssignedHomeworkModels.Load.Response) {
        self.loadBase = loadResponse
    }

    func load(specialistId: String) async -> AssignedHomeworkModels.Load.Response { loadBase }

    func create(request: AssignedHomeworkModels.Create.Request) async -> HomeworkAssignment? {
        createResult
    }

    func publishToCloud(
        assignment: HomeworkAssignment,
        specialistId: String,
        familyId: String
    ) async {
        publishToCloudCallCount += 1
        lastPublishedSpecialistId = specialistId
        lastPublishedFamilyId = familyId
    }

    func assignments(forChild childId: String) -> [HomeworkAssignment] { [] }

    func fetchAssignments(childId: String, familyId: String) async -> [HomeworkAssignment] {
        fetchResult
    }

    func updateExerciseStatus(
        request: AssignedHomeworkModels.UpdateStatus.Request
    ) async -> AssignedHomeworkModels.UpdateStatus.Response {
        updateStatusResult
    }

    func assignmentsStream(
        childId: String,
        familyId: String
    ) -> AsyncStream<[HomeworkAssignment]> {
        AsyncStream { continuation in continuation.finish() }
    }
}

@MainActor
private func makeInteractorSUT(
    specialistId: String = "spec-1",
    familyId: String = "fam-1"
) -> (AssignedHomeworkInteractor, SpyAssignedHomeworkPresenterExt, SpyAssignedHomeworkWorkerExt) {
    let loadResponse = AssignedHomeworkModels.Load.Response(
        children: [.init(id: "child-1", name: "Миша")],
        assignments: [],
        availableTemplates: AssignedHomeworkWorker.assignableTemplates
    )
    let worker = SpyAssignedHomeworkWorkerExt(loadResponse: loadResponse)
    let haptic = SpyHapticService()
    let interactor = AssignedHomeworkInteractor(
        specialistId: specialistId,
        familyId: familyId,
        worker: worker,
        hapticService: haptic
    )
    let spy = SpyAssignedHomeworkPresenterExt()
    interactor.presenter = spy
    return (interactor, spy, worker)
}

@MainActor
final class AssignedHomeworkInteractorSyncTests: XCTestCase {

    // 7. create() with success calls publishToCloud with correct specialistId
    func test_create_callsPublishToCloud_withSpecialistId() async {
        let (sut, spy, worker) = makeInteractorSUT(specialistId: "spec-99", familyId: "fam-42")
        let assignment = makeAssignment()
        worker.createResult = assignment

        await sut.create(request: .init(
            childId: "child-1",
            templateRaws: ["sorting"],
            repeatsPerExercise: 3,
            dueInDays: 3,
            comment: "Тест"
        ))

        XCTAssertEqual(worker.publishToCloudCallCount, 1)
        XCTAssertEqual(worker.lastPublishedSpecialistId, "spec-99")
        XCTAssertEqual(worker.lastPublishedFamilyId, "fam-42")
        XCTAssertEqual(spy.lastCreate?.didSucceed, true)
    }

    // 7b. create() with failure does NOT call publishToCloud
    func test_create_failure_doesNotCallPublishToCloud() async {
        let (sut, spy, worker) = makeInteractorSUT()
        worker.createResult = nil

        await sut.create(request: .init(
            childId: "",
            templateRaws: [],
            repeatsPerExercise: 0,
            dueInDays: 0,
            comment: ""
        ))

        XCTAssertEqual(worker.publishToCloudCallCount, 0)
        XCTAssertEqual(spy.lastCreate?.didSucceed, false)
    }

    // 8. updateExerciseStatus delegates to worker and calls presenter
    func test_updateExerciseStatus_delegatesToWorkerAndPresenter() async {
        let (sut, spy, worker) = makeInteractorSUT()
        let a = makeAssignment()
        worker.updateStatusResult = .init(didSucceed: true, updatedAssignment: a)

        await sut.updateExerciseStatus(request: .init(
            assignmentId: a.id,
            exerciseId: "ex-1",
            completedRepeats: 3
        ))

        XCTAssertEqual(spy.updateStatusCount, 1)
        XCTAssertTrue(spy.lastUpdateStatus?.didSucceed == true)
    }

    // 9. loadForFamily fetches from worker and calls presentFamilyLoad
    func test_loadForFamily_fetchesAndPresents() async {
        let (sut, spy, worker) = makeInteractorSUT()
        let a = makeAssignment(childId: "child-1")
        worker.fetchResult = [a]

        await sut.loadForFamily(request: .init(childId: "child-1", familyId: "fam-1"))

        XCTAssertEqual(spy.familyLoadCount, 1)
        XCTAssertEqual(spy.lastFamilyLoad?.assignments.count, 1)
    }
}

// MARK: - Tests 10, 11: Presenter

@MainActor
final class AssignedHomeworkPresenterSyncTests: XCTestCase {

    private func makePresenter() -> (AssignedHomeworkPresenter, AssignedHomeworkViewModelHolder) {
        let holder = AssignedHomeworkViewModelHolder()
        let presenter = AssignedHomeworkPresenter(displayLogic: holder)
        return (presenter, holder)
    }

    // 10. presentFamilyLoad builds AssignmentRowViewModels
    func test_presentFamilyLoad_buildsViewModels() async {
        let (presenter, holder) = makePresenter()
        let assignments = [makeAssignment(), makeAssignment(childId: "child-2")]
        let response = AssignedHomeworkModels.FamilyLoad.Response(assignments: assignments)
        await presenter.presentFamilyLoad(response: response)
        XCTAssertEqual(holder.familyLoadVM?.assignments.count, 2)
    }

    // 10b. presentFamilyLoad with empty list uses emptyStateText
    func test_presentFamilyLoad_emptyState() async {
        let (presenter, holder) = makePresenter()
        await presenter.presentFamilyLoad(response: .init(assignments: []))
        XCTAssertNotNil(holder.familyLoadVM?.emptyStateText)
        XCTAssertTrue(holder.familyLoadVM?.assignments.isEmpty == true)
    }

    // 11. presentUpdateStatus builds progressLabel for partial completion
    func test_presentUpdateStatus_buildsProgressLabel() async {
        let (presenter, holder) = makePresenter()
        var a = makeAssignment()
        a.exercises[0] = HomeworkExerciseItem(
            id: "ex-1", templateRaw: "sorting", repeats: 3, completedRepeats: 3
        )
        let response = AssignedHomeworkModels.UpdateStatus.Response(
            didSucceed: true,
            updatedAssignment: a
        )
        await presenter.presentUpdateStatus(response: response)
        XCTAssertTrue(holder.lastUpdateStatus?.didSucceed == true)
        XCTAssertFalse(holder.lastUpdateStatus?.progressLabel.isEmpty == true)
    }

    // 11b. presentUpdateStatus with no updatedAssignment gives empty progressLabel
    func test_presentUpdateStatus_noAssignment_emptyProgress() async {
        let (presenter, holder) = makePresenter()
        await presenter.presentUpdateStatus(
            response: .init(didSucceed: false, updatedAssignment: nil)
        )
        XCTAssertTrue(holder.lastUpdateStatus?.progressLabel.isEmpty == true)
    }
}

// MARK: - Test 12: Worker invalid request does not write to repo

@MainActor
final class AssignedHomeworkWorkerSyncTests: XCTestCase {

    private func makeWorker() -> (AssignedHomeworkWorker, MockHomeworkRepository, UserDefaults) {
        let suiteName = "test.homeworkSync.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("UserDefaults init failed")
        }
        let childRepo = MockChildRepository(children: [
            ChildProfileDTO(id: "child-1", name: "Миша", age: 6,
                            targetSounds: ["Р"], parentId: "p-1")
        ])
        let homeworkRepo = MockHomeworkRepository()
        let worker = AssignedHomeworkWorker(
            childRepository: childRepo,
            homeworkRepository: homeworkRepo,
            defaults: defaults
        )
        return (worker, homeworkRepo, defaults)
    }

    // 12. create() with invalid request returns nil and does NOT call publish
    func test_create_invalidRequest_returnsNilAndNoPublish() async {
        let (worker, homeworkRepo, _) = makeWorker()
        let result = await worker.create(request: .init(
            childId: "",
            templateRaws: [],
            repeatsPerExercise: 0,
            dueInDays: 0,
            comment: ""
        ))
        XCTAssertNil(result)
        // Invalid create → publishToCloud never called → nothing in repo
        let stored = await homeworkRepo.fetchAssignments(childId: "", familyId: "fam-1")
        XCTAssertTrue(stored.isEmpty)
    }

    // 12b. create() valid → assignment persisted locally + publishToCloud is available
    func test_create_valid_persistsLocally() async {
        let (worker, _, _) = makeWorker()
        let result = await worker.create(request: .init(
            childId: "child-1",
            templateRaws: ["sorting", "memory"],
            repeatsPerExercise: 3,
            dueInDays: 5,
            comment: "Делать дома"
        ))
        XCTAssertNotNil(result)
        let stored = worker.assignments(forChild: "child-1")
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.exercises.count, 2)
    }

    // Worker.updateExerciseStatus patches local + calls repo
    func test_updateExerciseStatus_patchesLocalAndCallsRepo() async {
        let (worker, homeworkRepo, _) = makeWorker()
        let a = makeAssignment()
        // Seed in repo
        await homeworkRepo.injectAssignment(a, familyId: "fam-1")

        let response = await worker.updateExerciseStatus(request: .init(
            assignmentId: a.id,
            exerciseId: "ex-1",
            completedRepeats: 3
        ))
        // repo.updateExerciseStatus is counted
        let repoCallCount = await homeworkRepo.updateStatusCallCount
        XCTAssertEqual(repoCallCount, 1)
        // Response reflects success (repo mock always succeeds)
        XCTAssertTrue(response.didSucceed)
    }

    // Worker.fetchAssignments merges remote into local
    func test_fetchAssignments_mergesRemoteIntoLocal() async {
        let (worker, homeworkRepo, _) = makeWorker()
        let a = makeAssignment(childId: "child-1")
        await homeworkRepo.injectAssignment(a, familyId: "fam-1")

        let fetched = await worker.fetchAssignments(childId: "child-1", familyId: "fam-1")
        XCTAssertEqual(fetched.count, 1)
        // Now local also has it
        let local = worker.assignments(forChild: "child-1")
        XCTAssertEqual(local.count, 1)
        XCTAssertEqual(local.first?.id, a.id)
    }
}
