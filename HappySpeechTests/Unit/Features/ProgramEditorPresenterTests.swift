@testable import HappySpeech
import XCTest

// MARK: - ProgramEditorPresenterTests
//
// Phase 2.6 batch 2 v25 — покрытие ProgramEditorPresenter (40% → цель ≥90%).

@MainActor
final class ProgramEditorPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: ProgramEditorDisplayLogic {
        var loadProgramVM: ProgramEditorModels.LoadProgram.ViewModel?
        var addBlockVM: ProgramEditorModels.AddBlock.ViewModel?
        var removeBlockVM: ProgramEditorModels.RemoveBlock.ViewModel?
        var moveBlockVM: ProgramEditorModels.MoveBlock.ViewModel?
        var saveProgramVM: ProgramEditorModels.SaveProgram.ViewModel?
        var validationVM: ProgramEditorModels.ValidateProgram.ViewModel?
        var validationWarningMessage: String?
        var assignToChildVM: ProgramEditorModels.AssignToChild.ViewModel?

        func displayLoadProgram(_ viewModel: ProgramEditorModels.LoadProgram.ViewModel) { loadProgramVM = viewModel }
        func displayAddBlock(_ viewModel: ProgramEditorModels.AddBlock.ViewModel) { addBlockVM = viewModel }
        func displayRemoveBlock(_ viewModel: ProgramEditorModels.RemoveBlock.ViewModel) { removeBlockVM = viewModel }
        func displayMoveBlock(_ viewModel: ProgramEditorModels.MoveBlock.ViewModel) { moveBlockVM = viewModel }
        func displaySaveProgram(_ viewModel: ProgramEditorModels.SaveProgram.ViewModel) { saveProgramVM = viewModel }
        func displayValidation(_ viewModel: ProgramEditorModels.ValidateProgram.ViewModel) { validationVM = viewModel }
        func displayValidationWarning(_ message: String) { validationWarningMessage = message }
        func displayAssignToChild(_ viewModel: ProgramEditorModels.AssignToChild.ViewModel) { assignToChildVM = viewModel }
    }

    private func makeSUT() -> (ProgramEditorPresenter, DisplaySpy) {
        let presenter = ProgramEditorPresenter()
        let spy = DisplaySpy()
        presenter.display = spy
        return (presenter, spy)
    }

    private func makeBlock(
        type: ProgramBlockType = .syllables,
        durationMinutes: Int = 5
    ) -> ProgramBlock {
        ProgramBlock(id: UUID(), type: type, durationMinutes: durationMinutes)
    }

    private func makeProgram(blocks: [ProgramBlock] = []) -> Program {
        Program(childId: "c-1", blocks: blocks, specialistNotes: "", updatedAt: Date())
    }

    // MARK: - presentLoadProgram

    func test_presentLoadProgram_callsDisplay() async {
        let (sut, spy) = makeSUT()
        let blocks = [makeBlock(type: .syllables, durationMinutes: 5)]
        let program = makeProgram(blocks: blocks)
        await sut.presentLoadProgram(.init(program: program, availableBlockTypes: ProgramBlockType.allCases))
        XCTAssertNotNil(spy.loadProgramVM)
    }

    func test_presentLoadProgram_totalDurationSummed() async {
        let (sut, spy) = makeSUT()
        let blocks = [makeBlock(durationMinutes: 3), makeBlock(durationMinutes: 7)]
        let program = makeProgram(blocks: blocks)
        await sut.presentLoadProgram(.init(program: program, availableBlockTypes: []))
        XCTAssertEqual(spy.loadProgramVM?.totalDurationMinutes, 10)
    }

    func test_presentLoadProgram_validProgram_isValidTrue() async {
        let (sut, spy) = makeSUT()
        // isValid requires: total 1-30, has production block, no consecutive breaks
        let blocks = [
            makeBlock(type: .warmup, durationMinutes: 2),
            makeBlock(type: .syllables, durationMinutes: 5),
            makeBlock(type: .coolDown, durationMinutes: 1)
        ]
        let program = makeProgram(blocks: blocks)
        await sut.presentLoadProgram(.init(program: program, availableBlockTypes: []))
        XCTAssertTrue(spy.loadProgramVM?.isValid ?? false)
    }

    func test_presentLoadProgram_emptyBlocks_isValidFalse() async {
        let (sut, spy) = makeSUT()
        let program = makeProgram(blocks: [])
        await sut.presentLoadProgram(.init(program: program, availableBlockTypes: []))
        XCTAssertFalse(spy.loadProgramVM?.isValid ?? true)
    }

    func test_presentLoadProgram_warningsPassedThrough() async {
        let (sut, spy) = makeSUT()
        let program = makeProgram(blocks: [])
        await sut.presentLoadProgram(.init(program: program, availableBlockTypes: [], validationWarnings: ["Нет производственных блоков"]))
        XCTAssertEqual(spy.loadProgramVM?.validationWarnings.count, 1)
    }

    // MARK: - isValid static method

    func test_isValid_consecutiveBreaks_returnsFalse() {
        let blocks = [
            makeBlock(type: .breakRest, durationMinutes: 2),
            makeBlock(type: .breakRest, durationMinutes: 2),
            makeBlock(type: .syllables, durationMinutes: 5)
        ]
        XCTAssertFalse(ProgramEditorPresenter.isValid(blocks))
    }

    func test_isValid_tooLong_returnsFalse() {
        let blocks = [makeBlock(type: .syllables, durationMinutes: 31)]
        XCTAssertFalse(ProgramEditorPresenter.isValid(blocks))
    }

    func test_isValid_noProductionBlock_returnsFalse() {
        let blocks = [makeBlock(type: .warmup, durationMinutes: 5)]
        XCTAssertFalse(ProgramEditorPresenter.isValid(blocks))
    }

    func test_isValid_hasPhrasesBlock_returnsTrue() {
        let blocks = [makeBlock(type: .phrases, durationMinutes: 10)]
        XCTAssertTrue(ProgramEditorPresenter.isValid(blocks))
    }

    // MARK: - presentAddBlock

    func test_presentAddBlock_callsDisplay() async {
        let (sut, spy) = makeSUT()
        let blocks = [makeBlock()]
        await sut.presentAddBlock(.init(updatedBlocks: blocks, totalDurationMinutes: 5))
        XCTAssertNotNil(spy.addBlockVM)
    }

    func test_presentAddBlock_totalDurationPassedThrough() async {
        let (sut, spy) = makeSUT()
        await sut.presentAddBlock(.init(updatedBlocks: [], totalDurationMinutes: 12))
        XCTAssertEqual(spy.addBlockVM?.totalDurationMinutes, 12)
    }

    func test_presentAddBlock_warningsPassedThrough() async {
        let (sut, spy) = makeSUT()
        await sut.presentAddBlock(.init(updatedBlocks: [], validationWarnings: ["Предупреждение"], totalDurationMinutes: 0))
        XCTAssertEqual(spy.addBlockVM?.validationWarnings.count, 1)
    }

    // MARK: - presentRemoveBlock

    func test_presentRemoveBlock_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentRemoveBlock(.init(updatedBlocks: [], totalDurationMinutes: 0))
        XCTAssertNotNil(spy.removeBlockVM)
    }

    func test_presentRemoveBlock_blocksPassedThrough() async {
        let (sut, spy) = makeSUT()
        let blocks = [makeBlock(), makeBlock()]
        await sut.presentRemoveBlock(.init(updatedBlocks: blocks, totalDurationMinutes: 10))
        XCTAssertEqual(spy.removeBlockVM?.blocks.count, 2)
    }

    // MARK: - presentMoveBlock

    func test_presentMoveBlock_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentMoveBlock(.init(updatedBlocks: []))
        XCTAssertNotNil(spy.moveBlockVM)
    }

    func test_presentMoveBlock_blocksPassedThrough() async {
        let (sut, spy) = makeSUT()
        let blocks = [makeBlock(type: .warmup), makeBlock(type: .syllables)]
        await sut.presentMoveBlock(.init(updatedBlocks: blocks))
        XCTAssertEqual(spy.moveBlockVM?.blocks.count, 2)
    }

    // MARK: - presentSaveProgram

    func test_presentSaveProgram_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentSaveProgram(.init(savedAt: Date()))
        XCTAssertNotNil(spy.saveProgramVM)
    }

    func test_presentSaveProgram_confirmationNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentSaveProgram(.init(savedAt: Date()))
        XCTAssertFalse(spy.saveProgramVM?.confirmationMessage.isEmpty ?? true)
    }

    // MARK: - presentValidation

    func test_presentValidation_valid_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentValidation(.init(isValid: true, warnings: [], errors: [], totalDurationMinutes: 10))
        XCTAssertNotNil(spy.validationVM)
        XCTAssertTrue(spy.validationVM?.isValid ?? false)
    }

    func test_presentValidation_invalid_summaryContainsErrors() async {
        let (sut, spy) = makeSUT()
        await sut.presentValidation(.init(isValid: false, warnings: [], errors: ["Нет блоков"], totalDurationMinutes: 0))
        XCTAssertFalse(spy.validationVM?.isValid ?? true)
        XCTAssertFalse(spy.validationVM?.summary.isEmpty ?? true)
    }

    func test_presentValidation_warningsPassedThrough() async {
        let (sut, spy) = makeSUT()
        await sut.presentValidation(.init(isValid: true, warnings: ["Проверьте длительность"], errors: [], totalDurationMinutes: 5))
        XCTAssertEqual(spy.validationVM?.warnings.count, 1)
    }

    func test_presentValidation_durationPassedThrough() async {
        let (sut, spy) = makeSUT()
        await sut.presentValidation(.init(isValid: true, warnings: [], errors: [], totalDurationMinutes: 15))
        XCTAssertEqual(spy.validationVM?.totalDurationMinutes, 15)
    }

    // MARK: - presentValidationWarning

    func test_presentValidationWarning_messagePassedThrough() async {
        let (sut, spy) = makeSUT()
        await sut.presentValidationWarning(.init(message: "Предупреждение: длительность превышена"))
        XCTAssertEqual(spy.validationWarningMessage, "Предупреждение: длительность превышена")
    }

    // MARK: - presentAssignToChild

    func test_presentAssignToChild_success_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentAssignToChild(.init(success: true, errorMessage: nil))
        XCTAssertNotNil(spy.assignToChildVM)
        XCTAssertTrue(spy.assignToChildVM?.success ?? false)
    }

    func test_presentAssignToChild_success_messageNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentAssignToChild(.init(success: true, errorMessage: nil))
        XCTAssertFalse(spy.assignToChildVM?.message.isEmpty ?? true)
    }

    func test_presentAssignToChild_failure_isNotSuccess() async {
        let (sut, spy) = makeSUT()
        await sut.presentAssignToChild(.init(success: false, errorMessage: "Ребёнок не найден"))
        XCTAssertFalse(spy.assignToChildVM?.success ?? true)
    }

    func test_presentAssignToChild_failure_usesErrorMessage() async {
        let (sut, spy) = makeSUT()
        let errorMsg = "Ребёнок не найден"
        await sut.presentAssignToChild(.init(success: false, errorMessage: errorMsg))
        XCTAssertEqual(spy.assignToChildVM?.message, errorMsg)
    }

    func test_presentAssignToChild_failure_noErrorMessage_usesDefault() async {
        let (sut, spy) = makeSUT()
        await sut.presentAssignToChild(.init(success: false, errorMessage: nil))
        XCTAssertFalse(spy.assignToChildVM?.message.isEmpty ?? true)
    }
}
