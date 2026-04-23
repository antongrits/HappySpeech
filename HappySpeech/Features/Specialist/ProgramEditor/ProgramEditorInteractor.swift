import Foundation
import OSLog

// MARK: - ProgramEditorBusinessLogic

@MainActor
protocol ProgramEditorBusinessLogic: AnyObject {
    func loadProgram(_ request: ProgramEditorModels.LoadProgram.Request) async
    func addBlock(_ request: ProgramEditorModels.AddBlock.Request) async
    func removeBlock(_ request: ProgramEditorModels.RemoveBlock.Request) async
    func moveBlock(_ request: ProgramEditorModels.MoveBlock.Request) async
    func saveProgram(_ request: ProgramEditorModels.SaveProgram.Request) async
}

// MARK: - ProgramEditorInteractor

/// Stateful VIP interactor for the specialist program editor. Owns the draft
/// `Program` in memory and mediates validation rules:
///   - total duration ≤ 30 minutes
///   - at least one production block (articulation / syllables / words)
///   - break block cannot be adjacent to another break
@MainActor
final class ProgramEditorInteractor: ProgramEditorBusinessLogic {

    var presenter: (any ProgramEditorPresentationLogic)?

    private var currentProgram: Program
    private let logger = Logger(subsystem: "ru.happyspeech", category: "ProgramEditor")

    init(seed: Program? = nil) {
        self.currentProgram = seed ?? Program(
            childId: "",
            blocks: ProgramEditorInteractor.defaultTemplate(),
            specialistNotes: "",
            updatedAt: Date()
        )
    }

    // MARK: - Load

    func loadProgram(_ request: ProgramEditorModels.LoadProgram.Request) async {
        currentProgram = Program(
            childId: request.childId,
            blocks: currentProgram.blocks.isEmpty
                ? ProgramEditorInteractor.defaultTemplate()
                : currentProgram.blocks,
            specialistNotes: currentProgram.specialistNotes,
            updatedAt: currentProgram.updatedAt
        )
        await presenter?.presentLoadProgram(.init(
            program: currentProgram,
            availableBlockTypes: ProgramBlockType.allCases
        ))
    }

    // MARK: - Mutations

    func addBlock(_ request: ProgramEditorModels.AddBlock.Request) async {
        let block = ProgramBlock(
            type: request.type,
            durationMinutes: max(1, min(15, request.durationMinutes)),
            targetSound: request.targetSound
        )
        currentProgram.blocks.append(block)
        currentProgram.updatedAt = Date()
        await presenter?.presentAddBlock(.init(updatedBlocks: currentProgram.blocks))
    }

    func removeBlock(_ request: ProgramEditorModels.RemoveBlock.Request) async {
        currentProgram.blocks.removeAll { $0.id == request.blockId }
        currentProgram.updatedAt = Date()
        await presenter?.presentRemoveBlock(.init(updatedBlocks: currentProgram.blocks))
    }

    func moveBlock(_ request: ProgramEditorModels.MoveBlock.Request) async {
        guard let oldIndex = currentProgram.blocks.firstIndex(where: { $0.id == request.blockId })
        else { return }
        let block = currentProgram.blocks.remove(at: oldIndex)
        let targetIndex = max(0, min(currentProgram.blocks.count, request.targetIndex))
        currentProgram.blocks.insert(block, at: targetIndex)
        currentProgram.updatedAt = Date()
        await presenter?.presentMoveBlock(.init(updatedBlocks: currentProgram.blocks))
    }

    func saveProgram(_ request: ProgramEditorModels.SaveProgram.Request) async {
        currentProgram = Program(
            childId: request.childId,
            blocks: request.blocks,
            specialistNotes: request.notes,
            updatedAt: Date()
        )
        logger.info("program saved child=\(request.childId, privacy: .private) blocks=\(request.blocks.count, privacy: .public)")
        await presenter?.presentSaveProgram(.init(savedAt: currentProgram.updatedAt))
    }

    // MARK: - Test hook

    /// Exposed for unit tests to inspect internal state without going through
    /// the presenter chain.
    func _currentProgram() -> Program { currentProgram }

    // MARK: - Defaults

    static func defaultTemplate() -> [ProgramBlock] {
        [
            ProgramBlock(type: .warmup, durationMinutes: 2),
            ProgramBlock(type: .articulationGymnastics, durationMinutes: 3),
            ProgramBlock(type: .syllables, durationMinutes: 5, targetSound: "Р"),
            ProgramBlock(type: .wordsInitial, durationMinutes: 4, targetSound: "Р"),
            ProgramBlock(type: .breakRest, durationMinutes: 1),
            ProgramBlock(type: .minimalPairs, durationMinutes: 2, targetSound: "Р/Л"),
            ProgramBlock(type: .coolDown, durationMinutes: 1),
        ]
    }
}
