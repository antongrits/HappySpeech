import XCTest
@testable import HappySpeech

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
    }

    private func makeSUT() -> (ProgramEditorInteractor, SpyPresenter) {
        let i = ProgramEditorInteractor()
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
        XCTAssertEqual(spy.lastBlocks[2].id, firstId)   // inserted at index 3 after removal shifts
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
            ProgramBlock(type: .breakRest, durationMinutes: 1),
        ]
        XCTAssertFalse(ProgramEditorPresenter.isValid(blocks))
    }

    func test_isValid_defaultTemplate_true() {
        XCTAssertTrue(ProgramEditorPresenter.isValid(ProgramEditorInteractor.defaultTemplate()))
    }
}
