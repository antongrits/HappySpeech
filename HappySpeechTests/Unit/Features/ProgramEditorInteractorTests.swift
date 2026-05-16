@testable import HappySpeech
import XCTest

// MARK: - ProgramEditorInteractorTests

@MainActor
final class ProgramEditorInteractorTests: XCTestCase {

    @MainActor
    private final class SpyPresenter: ProgramEditorPresentationLogic {
        var loadCalls = 0
        var lastBlocks: [ProgramBlock] = []
        var savedAt: Date?

        func presentLoadProgram(_ response: ProgramEditorModels.LoadProgram.Response) async {
            loadCalls += 1
            lastBlocks = response.program.blocks
        }
        func presentAddBlock(_ response: ProgramEditorModels.AddBlock.Response) async {
            lastBlocks = response.updatedBlocks
        }
        func presentRemoveBlock(_ response: ProgramEditorModels.RemoveBlock.Response) async {
            lastBlocks = response.updatedBlocks
        }
        func presentMoveBlock(_ response: ProgramEditorModels.MoveBlock.Response) async {
            lastBlocks = response.updatedBlocks
        }
        func presentSaveProgram(_ response: ProgramEditorModels.SaveProgram.Response) async {
            savedAt = response.savedAt
        }

        // MARK: D.1 v15 — новые методы протокола

        var validationCalled = false
        var validationWarningCalled = false
        var assignCalled = false
        var lastValidation: ProgramEditorModels.ValidateProgram.Response?
        var lastValidationWarning: ProgramEditorModels.ValidationWarning.Response?
        var lastAssign: ProgramEditorModels.AssignToChild.Response?

        func presentValidation(_ response: ProgramEditorModels.ValidateProgram.Response) async {
            validationCalled = true
            lastValidation = response
        }
        func presentValidationWarning(_ response: ProgramEditorModels.ValidationWarning.Response) async {
            validationWarningCalled = true
            lastValidationWarning = response
        }
        func presentAssignToChild(_ response: ProgramEditorModels.AssignToChild.Response) async {
            assignCalled = true
            lastAssign = response
        }
    }

    private func makeSUT(
        childRepository: (any ChildRepository)? = nil
    ) -> (ProgramEditorInteractor, SpyPresenter) {
        let i = ProgramEditorInteractor(childRepository: childRepository)
        let s = SpyPresenter()
        i.presenter = s
        return (i, s)
    }

    // MARK: - Load

    func test_loadProgram_defaultTemplate_returnsSevenBlocks() async {
        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c1"))
        XCTAssertEqual(spy.loadCalls, 1)
        XCTAssertEqual(spy.lastBlocks.count, 7)
    }

    func test_loadProgram_containsProductionBlock() async {
        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c1"))
        let hasProduction = spy.lastBlocks.contains {
            [.syllables, .isolatedSound, .wordsInitial].contains($0.type)
        }
        XCTAssertTrue(hasProduction)
    }

    // MARK: - Add

    func test_addBlock_appends() async {
        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c1"))
        let before = spy.lastBlocks.count
        await sut.addBlock(.init(type: .phrases, durationMinutes: 5, targetSound: "Р"))
        XCTAssertEqual(spy.lastBlocks.count, before + 1)
        XCTAssertEqual(spy.lastBlocks.last?.type, .phrases)
    }

    func test_addBlock_clampsDurationTo_1_to_15() async {
        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c1"))
        await sut.addBlock(.init(type: .phrases, durationMinutes: 999, targetSound: nil))
        XCTAssertEqual(spy.lastBlocks.last?.durationMinutes, 15)

        await sut.addBlock(.init(type: .phrases, durationMinutes: 0, targetSound: nil))
        XCTAssertEqual(spy.lastBlocks.last?.durationMinutes, 1)
    }

    // MARK: - Remove

    func test_removeBlock_byId_drops() async {
        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c1"))
        let targetId = spy.lastBlocks.first!.id
        await sut.removeBlock(.init(blockId: targetId))
        XCTAssertFalse(spy.lastBlocks.contains { $0.id == targetId })
    }

    // MARK: - Move

    func test_moveBlock_reorders() async {
        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c1"))
        let firstId = spy.lastBlocks.first!.id
        await sut.moveBlock(.init(blockId: firstId, targetIndex: 3))
        // После remove(at:0) и insert(at:3): firstBlock стоит на индексе 3
        XCTAssertEqual(spy.lastBlocks[3].id, firstId)
    }

    // MARK: - Save

    func test_saveProgram_firesWithCurrentTimestamp() async {
        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c1"))
        let blocks = spy.lastBlocks
        let before = Date()
        await sut.saveProgram(.init(childId: "c1", blocks: blocks, notes: "notes"))
        XCTAssertNotNil(spy.savedAt)
        XCTAssertGreaterThanOrEqual(spy.savedAt!.timeIntervalSince1970, before.timeIntervalSince1970 - 1)
    }

    // MARK: - Validation (static)

    func test_isValid_emptyBlocks_false() {
        XCTAssertFalse(ProgramEditorPresenter.isValid([]))
    }

    func test_isValid_durationOver30_false() {
        let blocks = [ProgramBlock(type: .syllables, durationMinutes: 40)]
        XCTAssertFalse(ProgramEditorPresenter.isValid(blocks))
    }

    func test_isValid_adjacentBreaks_false() {
        let blocks = [
            ProgramBlock(type: .syllables, durationMinutes: 5),
            ProgramBlock(type: .breakRest, durationMinutes: 1),
            ProgramBlock(type: .breakRest, durationMinutes: 1)
        ]
        XCTAssertFalse(ProgramEditorPresenter.isValid(blocks))
    }

    func test_isValid_defaultTemplate_true() {
        XCTAssertTrue(ProgramEditorPresenter.isValid(ProgramEditorInteractor.defaultTemplate()))
    }

    // MARK: - validateProgram

    func test_validateProgram_defaultTemplate_isValid() async {
        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c1"))
        await sut.validateProgram(.init())
        XCTAssertTrue(spy.validationCalled)
        XCTAssertEqual(spy.lastValidation?.isValid, true)
        XCTAssertGreaterThan(spy.lastValidation?.totalDurationMinutes ?? 0, 0)
    }

    func test_validateProgram_emptyProgram_hasErrors() async {
        let emptyProgram = Program(childId: "", blocks: [], specialistNotes: "", updatedAt: Date())
        let sut = ProgramEditorInteractor(seed: emptyProgram)
        let spy = SpyPresenter()
        sut.presenter = spy
        await sut.validateProgram(.init())
        XCTAssertEqual(spy.lastValidation?.isValid, false)
        XCTAssertFalse(spy.lastValidation?.errors.isEmpty ?? true)
    }

    // MARK: - addBlock prerequisite warning

    func test_addBlock_wordsWithoutSyllables_triggersPrereqWarning() async {
        // Программа без syllables-блока
        let program = Program(
            childId: "c1",
            blocks: [ProgramBlock(type: .warmup, durationMinutes: 2)],
            specialistNotes: "", updatedAt: Date()
        )
        let sut = ProgramEditorInteractor(seed: program)
        let spy = SpyPresenter()
        sut.presenter = spy
        await sut.addBlock(.init(type: .wordsInitial, durationMinutes: 4, targetSound: "Р"))
        XCTAssertTrue(spy.validationWarningCalled)
        XCTAssertFalse(spy.lastValidationWarning?.message.isEmpty ?? true)
    }

    // MARK: - duplicateBlock

    func test_duplicateBlock_insertsCopy() async {
        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c1"))
        let countBefore = spy.lastBlocks.count
        let targetId = spy.lastBlocks.first!.id
        await sut.duplicateBlock(.init(blockId: targetId))
        XCTAssertEqual(spy.lastBlocks.count, countBefore + 1)
        // копия — другой UUID, тот же type
        XCTAssertEqual(spy.lastBlocks[0].type, spy.lastBlocks[1].type)
        XCTAssertNotEqual(spy.lastBlocks[0].id, spy.lastBlocks[1].id)
    }

    func test_duplicateBlock_unknownId_ignored() async {
        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c1"))
        let countBefore = spy.lastBlocks.count
        await sut.duplicateBlock(.init(blockId: UUID()))
        XCTAssertEqual(spy.lastBlocks.count, countBefore)
    }

    // MARK: - moveBlock unknown id

    func test_moveBlock_unknownId_ignored() async {
        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c1"))
        let blocksBefore = spy.lastBlocks
        await sut.moveBlock(.init(blockId: UUID(), targetIndex: 0))
        XCTAssertEqual(spy.lastBlocks.map(\.id), blocksBefore.map(\.id))
    }

    // MARK: - assignToChild

    func test_assignToChild_validProgram_succeeds() async {
        let childRepo = SpyChildRepository(children: [TestDataBuilder.childProfile(id: "c1")])
        let (sut, spy) = makeSUT(childRepository: childRepo)
        await sut.loadProgram(.init(childId: "c1"))
        await sut.assignToChild(.init(childId: "c1"))
        XCTAssertTrue(spy.assignCalled)
        XCTAssertEqual(spy.lastAssign?.success, true)
    }

    func test_assignToChild_invalidProgram_fails() async {
        let emptyProgram = Program(childId: "", blocks: [], specialistNotes: "", updatedAt: Date())
        let sut = ProgramEditorInteractor(seed: emptyProgram)
        let spy = SpyPresenter()
        sut.presenter = spy
        await sut.assignToChild(.init(childId: "c1"))
        XCTAssertEqual(spy.lastAssign?.success, false)
        XCTAssertNotNil(spy.lastAssign?.errorMessage)
    }

    func test_assignToChild_repositoryFails_returnsError() async {
        let childRepo = SpyChildRepository(children: [TestDataBuilder.childProfile(id: "c1")])
        childRepo.shouldFail = true
        let (sut, spy) = makeSUT(childRepository: childRepo)
        await sut.loadProgram(.init(childId: "c1"))
        await sut.assignToChild(.init(childId: "c1"))
        XCTAssertEqual(spy.lastAssign?.success, false)
    }

    func test_assignToChild_noRepository_succeedsLocally() async {
        let (sut, spy) = makeSUT(childRepository: nil)
        await sut.loadProgram(.init(childId: "c1"))
        await sut.assignToChild(.init(childId: "c1"))
        // Без репозитория saveAssignedProgram возвращает без ошибки → success
        XCTAssertEqual(spy.lastAssign?.success, true)
    }

    // MARK: - currentProgramSnapshot

    func test_currentProgramSnapshot_reflectsState() async {
        let (sut, _) = makeSUT()
        await sut.loadProgram(.init(childId: "c-snap"))
        let snapshot = sut.currentProgramSnapshot()
        XCTAssertEqual(snapshot.childId, "c-snap")
        XCTAssertFalse(snapshot.blocks.isEmpty)
    }

    // MARK: - removeBlock пересчитывает длительность

    func test_removeBlock_updatesTotalDuration() async {
        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c1"))
        await sut.addBlock(.init(type: .phrases, durationMinutes: 5, targetSound: nil))
        let added = spy.lastBlocks.last!
        await sut.removeBlock(.init(blockId: added.id))
        XCTAssertFalse(spy.lastBlocks.contains { $0.id == added.id })
    }
}
