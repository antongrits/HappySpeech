@testable import HappySpeech
import XCTest

// MARK: - Spy DisplayLogic

@MainActor
private final class SpyAssignedHomeworkDisplay: AssignedHomeworkDisplayLogic, @unchecked Sendable {
    var loadVM: AssignedHomeworkModels.Load.ViewModel?
    var createVM: AssignedHomeworkModels.Create.ViewModel?

    func displayLoad(viewModel: AssignedHomeworkModels.Load.ViewModel) async {
        loadVM = viewModel
    }
    func displayCreate(viewModel: AssignedHomeworkModels.Create.ViewModel) async {
        createVM = viewModel
    }
}

// MARK: - Presenter Tests

@MainActor
final class AssignedHomeworkPresenterTests: XCTestCase {

    private func makeSUT() -> (AssignedHomeworkPresenter, SpyAssignedHomeworkDisplay) {
        let display = SpyAssignedHomeworkDisplay()
        let sut = AssignedHomeworkPresenter(displayLogic: display)
        return (sut, display)
    }

    func test_presentLoad_buildsChildrenAndTemplates() async {
        let (sut, display) = makeSUT()
        await sut.presentLoad(response: .init(
            children: [.init(id: "child-1", name: "Миша")],
            assignments: [],
            availableTemplates: [.sorting, .memory]
        ))
        XCTAssertEqual(display.loadVM?.children.count, 1)
        XCTAssertEqual(display.loadVM?.templates.count, 2)
        XCTAssertTrue(display.loadVM?.assignments.isEmpty ?? false)
    }

    func test_presentLoad_buildsAssignmentRows() async {
        let (sut, display) = makeSUT()
        let assignment = HomeworkAssignment(
            childId: "child-1",
            dueDate: Date().addingTimeInterval(86_400),
            comment: "Тест",
            exercises: [
                .init(templateRaw: "sorting", repeats: 2, completedRepeats: 2),
                .init(templateRaw: "memory", repeats: 2)
            ]
        )
        await sut.presentLoad(response: .init(
            children: [.init(id: "child-1", name: "Миша")],
            assignments: [assignment],
            availableTemplates: [.sorting]
        ))
        XCTAssertEqual(display.loadVM?.assignments.count, 1)
        let row = display.loadVM?.assignments.first
        XCTAssertEqual(row?.childName, "Миша")
        XCTAssertEqual(row?.isComplete, false)
        XCTAssertFalse(row?.statusLabel.isEmpty ?? true)
    }

    func test_presentLoad_completeAssignment_marksComplete() async {
        let (sut, display) = makeSUT()
        let assignment = HomeworkAssignment(
            childId: "child-1",
            dueDate: Date(),
            comment: "",
            exercises: [.init(templateRaw: "sorting", repeats: 1, completedRepeats: 1)]
        )
        await sut.presentLoad(response: .init(
            children: [.init(id: "child-1", name: "Миша")],
            assignments: [assignment],
            availableTemplates: []
        ))
        XCTAssertEqual(display.loadVM?.assignments.first?.isComplete, true)
    }

    func test_presentCreate_success_message() async {
        let (sut, display) = makeSUT()
        await sut.presentCreate(response: .init(didSucceed: true, assignment: nil))
        XCTAssertEqual(display.createVM?.didSucceed, true)
        XCTAssertFalse(display.createVM?.message.isEmpty ?? true)
    }

    func test_presentCreate_failure_message() async {
        let (sut, display) = makeSUT()
        await sut.presentCreate(response: .init(didSucceed: false, assignment: nil))
        XCTAssertEqual(display.createVM?.didSucceed, false)
    }
}
