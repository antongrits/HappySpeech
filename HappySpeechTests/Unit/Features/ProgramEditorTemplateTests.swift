@testable import HappySpeech
import XCTest

// MARK: - ProgramEditorTemplateTests
//
// Tests for drag-drop reorder persistence and import/export round-trip.

@MainActor
final class ProgramEditorTemplateTests: XCTestCase {

    // MARK: - Spy Presenter

    @MainActor
    private final class SpyPresenter: ProgramEditorPresentationLogic {
        var lastBlocks: [ProgramBlock] = []
        var exportedURL: URL?
        var importedProgram: Program?
        var importFailureMessage: String?
        var warningMessage: String?

        func presentLoadProgram(_ response: ProgramEditorModels.LoadProgram.Response) async {
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
        func presentSaveProgram(_ response: ProgramEditorModels.SaveProgram.Response) async {}
        func presentValidation(_ response: ProgramEditorModels.ValidateProgram.Response) async {}
        func presentValidationWarning(_ response: ProgramEditorModels.ValidationWarning.Response) async {
            warningMessage = response.message
        }
        func presentAssignToChild(_ response: ProgramEditorModels.AssignToChild.Response) async {}
        func presentExportTemplate(_ response: ProgramEditorModels.ExportTemplate.Response) async {
            exportedURL = response.fileURL
        }
        func presentImportTemplate(_ response: ProgramEditorModels.ImportTemplate.Response) async {
            importedProgram = response.program
        }
        func presentImportTemplateFailure(_ response: ProgramEditorModels.ImportTemplate.FailureViewModel) async {
            importFailureMessage = response.errorMessage
        }
    }

    private func makeSUT() -> (ProgramEditorInteractor, SpyPresenter) {
        let sut = ProgramEditorInteractor()
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - Drag-drop reorder persists in state

    func test_moveBlock_reorders_firstBlockMovedToIndex3() async {
        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c-reorder"))
        let originalFirst = spy.lastBlocks.first!
        await sut.moveBlock(.init(blockId: originalFirst.id, targetIndex: 3))
        // After remove(at:0) and insert(at:3), the block is now at position 3
        XCTAssertEqual(spy.lastBlocks[3].id, originalFirst.id,
                       "Moved block must appear at target index in presenter's response")
    }

    func test_moveBlock_reorders_lastBlockMovedToFront() async {
        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c-reorder2"))
        let lastBlock = spy.lastBlocks.last!
        await sut.moveBlock(.init(blockId: lastBlock.id, targetIndex: 0))
        XCTAssertEqual(spy.lastBlocks.first!.id, lastBlock.id,
                       "Moving last block to index 0 should make it the first block")
    }

    func test_moveBlock_reorders_snapshotReflectsNewOrder() async {
        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c-snap"))
        let firstId = spy.lastBlocks.first!.id
        await sut.moveBlock(.init(blockId: firstId, targetIndex: 2))
        let snapshot = sut.currentProgramSnapshot()
        XCTAssertEqual(snapshot.blocks[2].id, firstId,
                       "currentProgramSnapshot must reflect the reordered state")
    }

    func test_moveBlock_multipleReorders_correctFinalOrder() async {
        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c-multi"))
        // Move block at index 0 → 2, then block at index 1 → 0
        let id0 = spy.lastBlocks[0].id
        await sut.moveBlock(.init(blockId: id0, targetIndex: 2))
        let id1 = spy.lastBlocks[0].id // now a different block is at 0
        await sut.moveBlock(.init(blockId: id1, targetIndex: spy.lastBlocks.count - 1))
        let snapshot = sut.currentProgramSnapshot()
        // Snapshot should have same total block count
        XCTAssertEqual(snapshot.blocks.count, 7,
                       "Reordering must not add or remove blocks")
        // All original IDs still present
        XCTAssertTrue(snapshot.blocks.contains { $0.id == id0 })
        XCTAssertTrue(snapshot.blocks.contains { $0.id == id1 })
    }

    // MARK: - Export produces valid file

    func test_exportTemplate_producesFileURL() async {
        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c-export"))
        await sut.exportTemplate(.init(
            childId: "c-export",
            blocks: sut.currentProgramSnapshot().blocks,
            notes: "Тест экспорта"
        ))
        XCTAssertNotNil(spy.exportedURL, "exportTemplate must produce a file URL via presenter")
        if let url = spy.exportedURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                          "Exported file must exist on disk")
        }
    }

    func test_exportTemplate_fileContainsVersionField() async throws {
        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c-version"))
        await sut.exportTemplate(.init(
            childId: "c-version",
            blocks: sut.currentProgramSnapshot().blocks,
            notes: ""
        ))
        let url = try XCTUnwrap(spy.exportedURL)
        let data = try Data(contentsOf: url)
        let json = try JSONDecoder().decode(ProgramTemplatePayload.self, from: data)
        XCTAssertEqual(json.version, ProgramTemplatePayload.currentVersion,
                       "Exported JSON must contain the current format version")
    }

    func test_exportTemplate_preservesBlockCount() async throws {
        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c-blocks"))
        let originalCount = sut.currentProgramSnapshot().blocks.count
        await sut.exportTemplate(.init(
            childId: "c-blocks",
            blocks: sut.currentProgramSnapshot().blocks,
            notes: ""
        ))
        let url = try XCTUnwrap(spy.exportedURL)
        let data = try Data(contentsOf: url)
        let json = try JSONDecoder().decode(ProgramTemplatePayload.self, from: data)
        XCTAssertEqual(json.blocks.count, originalCount,
                       "Exported block count must match the source program")
    }

    // MARK: - Import/Export round-trip

    func test_roundTrip_exportThenImport_preservesBlocks() async throws {
        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c-roundtrip"))
        let original = sut.currentProgramSnapshot()

        // Export
        await sut.exportTemplate(.init(
            childId: "c-roundtrip",
            blocks: original.blocks,
            notes: "Заметки специалиста"
        ))
        let exportURL = try XCTUnwrap(spy.exportedURL)

        // Import into a fresh interactor
        let (sut2, spy2) = makeSUT()
        await sut2.loadProgram(.init(childId: "c-roundtrip-2"))
        await sut2.importTemplate(.init(fileURL: exportURL))

        let imported = try XCTUnwrap(spy2.importedProgram)
        XCTAssertEqual(imported.blocks.count, original.blocks.count,
                       "Round-trip must preserve block count")
        XCTAssertEqual(
            imported.blocks.map(\.type),
            original.blocks.map(\.type),
            "Round-trip must preserve block types in order"
        )
        XCTAssertEqual(
            imported.blocks.map(\.durationMinutes),
            original.blocks.map(\.durationMinutes),
            "Round-trip must preserve block durations"
        )
    }

    func test_roundTrip_preservesSpecialistNotes() async throws {
        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c-notes"))
        let notes = "Особые рекомендации для ребёнка"

        await sut.exportTemplate(.init(
            childId: "c-notes",
            blocks: sut.currentProgramSnapshot().blocks,
            notes: notes
        ))
        let exportURL = try XCTUnwrap(spy.exportedURL)

        let (sut2, spy2) = makeSUT()
        await sut2.loadProgram(.init(childId: "c-notes-2"))
        await sut2.importTemplate(.init(fileURL: exportURL))

        let imported = try XCTUnwrap(spy2.importedProgram)
        XCTAssertEqual(imported.specialistNotes, notes,
                       "Round-trip must preserve specialist notes")
    }

    func test_roundTrip_preservesTargetSounds() async throws {
        let program = Program(
            childId: "c-sounds",
            blocks: [
                ProgramBlock(type: .syllables, durationMinutes: 4, targetSound: "Р"),
                ProgramBlock(type: .wordsInitial, durationMinutes: 4, targetSound: "Р"),
                ProgramBlock(type: .minimalPairs, durationMinutes: 3, targetSound: "Р/Л")
            ],
            specialistNotes: "",
            updatedAt: Date()
        )
        let (sut, spy) = makeSUT()
        // Use a seed program with target sounds
        let seededSUT = ProgramEditorInteractor(seed: program)
        seededSUT.presenter = spy
        await seededSUT.loadProgram(.init(childId: "c-sounds"))

        await seededSUT.exportTemplate(.init(
            childId: "c-sounds",
            blocks: seededSUT.currentProgramSnapshot().blocks,
            notes: ""
        ))
        let exportURL = try XCTUnwrap(spy.exportedURL)

        let (sut2, spy2) = makeSUT()
        await sut2.loadProgram(.init(childId: "c-sounds-2"))
        await sut2.importTemplate(.init(fileURL: exportURL))

        let imported = try XCTUnwrap(spy2.importedProgram)
        XCTAssertEqual(imported.blocks[0].targetSound, "Р")
        XCTAssertEqual(imported.blocks[2].targetSound, "Р/Л")
        _ = sut // suppress unused warning
    }

    // MARK: - Import failure — corrupt JSON

    func test_importTemplate_corruptJSON_firesFailure() async throws {
        let corruptData = Data("{ not valid json @@@".utf8)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("corrupt-test-\(UUID().uuidString).happyspeech")
        try corruptData.write(to: url)

        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c-corrupt"))
        await sut.importTemplate(.init(fileURL: url))

        XCTAssertNil(spy.importedProgram, "Corrupt JSON must not produce a program")
        XCTAssertNotNil(spy.importFailureMessage,
                        "Corrupt JSON must fire importTemplateFailure with an error message")
        XCTAssertFalse(spy.importFailureMessage?.isEmpty ?? true)
    }

    func test_importTemplate_wrongSchema_firesFailure() async throws {
        // Valid JSON but wrong schema (missing required fields)
        let badData = Data(#"{"foo": "bar"}"#.utf8)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wrong-schema-\(UUID().uuidString).json")
        try badData.write(to: url)

        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c-wrong"))
        await sut.importTemplate(.init(fileURL: url))

        XCTAssertNil(spy.importedProgram)
        XCTAssertNotNil(spy.importFailureMessage)
    }

    func test_importTemplate_emptyBlocksPayload_firesFailure() async throws {
        // Valid payload structure but no blocks
        let payload = ProgramTemplatePayload(program: Program(
            childId: "",
            blocks: [],
            specialistNotes: "",
            updatedAt: Date()
        ))
        let data = try JSONEncoder().encode(payload)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("empty-blocks-\(UUID().uuidString).happyspeech")
        try data.write(to: url)

        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c-empty"))
        await sut.importTemplate(.init(fileURL: url))

        XCTAssertNil(spy.importedProgram, "Import of payload with empty blocks must fail")
        XCTAssertNotNil(spy.importFailureMessage)
    }

    func test_importTemplate_doesNotCrashOnNonexistentFile() async {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString).happyspeech")

        let (sut, spy) = makeSUT()
        await sut.loadProgram(.init(childId: "c-missing"))
        // Must not crash or throw an unhandled error
        await sut.importTemplate(.init(fileURL: missingURL))

        XCTAssertNil(spy.importedProgram)
        XCTAssertNotNil(spy.importFailureMessage,
                        "Missing file must produce an error message, not a crash")
    }

    // MARK: - Worker unit tests (direct)

    func test_worker_export_roundTrip_preservesBlockTypes() throws {
        let worker = ProgramTemplateExportWorker()
        let program = Program(
            childId: "w-test",
            blocks: ProgramEditorInteractor.defaultTemplate(),
            specialistNotes: "заметки",
            updatedAt: Date()
        )
        let url = try worker.export(program: program)
        let imported = try worker.importProgram(from: url)
        XCTAssertEqual(
            imported.blocks.map(\.type),
            program.blocks.map(\.type)
        )
    }

    func test_worker_import_versionMismatch_throws() throws {
        // Craft a payload with a future version number
        struct FuturePayload: Encodable {
            let version: Int = 999
            let exportedAt: String = "2099-01-01T00:00:00Z"
            let childId: String = "x"
            let specialistNotes: String = ""
            let blocks: [ProgramBlock] = [ProgramBlock(type: .syllables, durationMinutes: 4)]
        }
        let data = try JSONEncoder().encode(FuturePayload())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("future-\(UUID().uuidString).happyspeech")
        try data.write(to: url)

        let worker = ProgramTemplateExportWorker()
        XCTAssertThrowsError(try worker.importProgram(from: url)) { error in
            if case let ProgramTemplateExportError.versionMismatch(found, required) = error {
                XCTAssertEqual(found, 999)
                XCTAssertEqual(required, ProgramTemplatePayload.currentVersion)
            } else {
                XCTFail("Expected versionMismatch error, got \(error)")
            }
        }
    }
}
