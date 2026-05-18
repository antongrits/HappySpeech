@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubAssignedHomeworkWorker: AssignedHomeworkWorkerProtocol {
    var loadResponse: AssignedHomeworkModels.Load.Response
    var createResult: HomeworkAssignment?
    private(set) var loadCount = 0
    private(set) var createCount = 0

    init(loadResponse: AssignedHomeworkModels.Load.Response) {
        self.loadResponse = loadResponse
    }

    func load(specialistId: String) async -> AssignedHomeworkModels.Load.Response {
        loadCount += 1
        return loadResponse
    }
    func create(
        request: AssignedHomeworkModels.Create.Request
    ) async -> HomeworkAssignment? {
        createCount += 1
        return createResult
    }
    func assignments(forChild childId: String) -> [HomeworkAssignment] {
        loadResponse.assignments.filter { $0.childId == childId }
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyAssignedHomeworkPresenter: AssignedHomeworkPresentationLogic, @unchecked Sendable {
    var loadCount = 0
    var createCount = 0
    var lastCreate: AssignedHomeworkModels.Create.Response?

    func presentLoad(response: AssignedHomeworkModels.Load.Response) async {
        loadCount += 1
    }
    func presentCreate(response: AssignedHomeworkModels.Create.Response) async {
        createCount += 1
        lastCreate = response
    }
}

// MARK: - Helpers

@MainActor
private func makeLoadResponse() -> AssignedHomeworkModels.Load.Response {
    .init(
        children: [.init(id: "child-1", name: "Миша")],
        assignments: [],
        availableTemplates: AssignedHomeworkWorker.assignableTemplates
    )
}

// MARK: - Interactor Tests

@MainActor
final class AssignedHomeworkInteractorTests: XCTestCase {

    private func makeSUT(
        createResult: HomeworkAssignment?
    ) -> (AssignedHomeworkInteractor, SpyAssignedHomeworkPresenter, StubAssignedHomeworkWorker) {
        let worker = StubAssignedHomeworkWorker(loadResponse: makeLoadResponse())
        worker.createResult = createResult
        let haptic = SpyHapticService()
        let sut = AssignedHomeworkInteractor(
            specialistId: "spec-1", worker: worker, hapticService: haptic
        )
        let spy = SpyAssignedHomeworkPresenter()
        sut.presenter = spy
        return (sut, spy, worker)
    }

    func test_load_presents() async {
        let (sut, spy, worker) = makeSUT(createResult: nil)
        await sut.load(request: .init(specialistId: "spec-1"))
        XCTAssertEqual(worker.loadCount, 1)
        XCTAssertEqual(spy.loadCount, 1)
    }

    func test_create_success_presentsAndReloads() async {
        let assignment = HomeworkAssignment(
            childId: "child-1",
            dueDate: Date().addingTimeInterval(3 * 86_400),
            comment: "Тест",
            exercises: [.init(templateRaw: "sorting", repeats: 3)]
        )
        let (sut, spy, worker) = makeSUT(createResult: assignment)
        await sut.create(request: .init(
            childId: "child-1",
            templateRaws: ["sorting"],
            repeatsPerExercise: 3,
            dueInDays: 3,
            comment: "Тест"
        ))
        XCTAssertEqual(worker.createCount, 1)
        XCTAssertEqual(spy.lastCreate?.didSucceed, true)
        // После создания список перезагружается.
        XCTAssertGreaterThanOrEqual(spy.loadCount, 1)
    }

    func test_create_failure_presentsFailure() async {
        let (sut, spy, _) = makeSUT(createResult: nil)
        await sut.create(request: .init(
            childId: "",
            templateRaws: [],
            repeatsPerExercise: 0,
            dueInDays: 0,
            comment: ""
        ))
        XCTAssertEqual(spy.lastCreate?.didSucceed, false)
    }
}

// MARK: - Model Tests

final class AssignedHomeworkModelTests: XCTestCase {

    func test_exerciseItem_isDone_whenRepeatsReached() {
        var item = HomeworkExerciseItem(templateRaw: "sorting", repeats: 3)
        XCTAssertFalse(item.isDone)
        item.completedRepeats = 3
        XCTAssertTrue(item.isDone)
    }

    func test_assignment_isComplete_whenAllExercisesDone() {
        let done = HomeworkExerciseItem(
            templateRaw: "sorting", repeats: 2, completedRepeats: 2
        )
        let pending = HomeworkExerciseItem(templateRaw: "memory", repeats: 2)
        let mixed = HomeworkAssignment(
            childId: "c", dueDate: Date(), comment: "",
            exercises: [done, pending]
        )
        XCTAssertFalse(mixed.isComplete)
        XCTAssertEqual(mixed.doneCount, 1)

        let allDone = HomeworkAssignment(
            childId: "c", dueDate: Date(), comment: "",
            exercises: [done]
        )
        XCTAssertTrue(allDone.isComplete)
    }

    func test_exerciseItem_templateResolves() {
        let item = HomeworkExerciseItem(templateRaw: "sorting", repeats: 1)
        XCTAssertEqual(item.template, .sorting)
    }

    func test_assignment_codableRoundTrip() throws {
        let original = HomeworkAssignment(
            childId: "child-1",
            dueDate: Date(timeIntervalSince1970: 1_700_000_000),
            comment: "Комментарий",
            exercises: [.init(templateRaw: "memory", repeats: 4)]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HomeworkAssignment.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.childId, "child-1")
        XCTAssertEqual(decoded.exercises.first?.templateRaw, "memory")
    }
}

// MARK: - Worker Storage Tests

@MainActor
final class AssignedHomeworkWorkerTests: XCTestCase {

    private func makeWorker() -> (AssignedHomeworkWorker, UserDefaults) {
        let suiteName = "test.assignedHomework.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Failed to create test UserDefaults")
        }
        let repo = MockChildRepository(children: [
            ChildProfileDTO(id: "child-1", name: "Миша", age: 6,
                            targetSounds: ["Р"], parentId: "p-1")
        ])
        return (AssignedHomeworkWorker(childRepository: repo, defaults: defaults), defaults)
    }

    func test_create_persistsAndQueryable() async {
        let (worker, _) = makeWorker()
        let created = await worker.create(request: .init(
            childId: "child-1",
            templateRaws: ["sorting", "memory"],
            repeatsPerExercise: 3,
            dueInDays: 5,
            comment: "Делать дома"
        ))
        XCTAssertNotNil(created)
        let stored = worker.assignments(forChild: "child-1")
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.exercises.count, 2)
    }

    func test_create_invalidRequest_returnsNil() async {
        let (worker, _) = makeWorker()
        let created = await worker.create(request: .init(
            childId: "",
            templateRaws: [],
            repeatsPerExercise: 0,
            dueInDays: 1,
            comment: ""
        ))
        XCTAssertNil(created)
    }

    func test_load_returnsChildrenAndTemplates() async {
        let (worker, _) = makeWorker()
        let response = await worker.load(specialistId: "spec-1")
        XCTAssertEqual(response.children.count, 1)
        XCTAssertFalse(response.availableTemplates.isEmpty)
    }
}
