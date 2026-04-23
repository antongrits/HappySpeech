import Foundation

// MARK: - ProgramEditorPresentationLogic

@MainActor
protocol ProgramEditorPresentationLogic: AnyObject {
    func presentLoadProgram(_ response: ProgramEditorModels.LoadProgram.Response) async
    func presentAddBlock(_ response: ProgramEditorModels.AddBlock.Response) async
    func presentRemoveBlock(_ response: ProgramEditorModels.RemoveBlock.Response) async
    func presentMoveBlock(_ response: ProgramEditorModels.MoveBlock.Response) async
    func presentSaveProgram(_ response: ProgramEditorModels.SaveProgram.Response) async
}

// MARK: - ProgramEditorPresenter

@MainActor
final class ProgramEditorPresenter: ProgramEditorPresentationLogic {

    weak var display: (any ProgramEditorDisplayLogic)?

    func presentLoadProgram(_ response: ProgramEditorModels.LoadProgram.Response) async {
        let total = response.program.blocks.map(\.durationMinutes).reduce(0, +)
        let vm = ProgramEditorModels.LoadProgram.ViewModel(
            blocks: response.program.blocks,
            totalDurationMinutes: total,
            isValid: Self.isValid(response.program.blocks)
        )
        display?.displayLoadProgram(vm)
    }

    func presentAddBlock(_ response: ProgramEditorModels.AddBlock.Response) async {
        let total = response.updatedBlocks.map(\.durationMinutes).reduce(0, +)
        display?.displayAddBlock(.init(blocks: response.updatedBlocks,
                                       totalDurationMinutes: total))
    }

    func presentRemoveBlock(_ response: ProgramEditorModels.RemoveBlock.Response) async {
        let total = response.updatedBlocks.map(\.durationMinutes).reduce(0, +)
        display?.displayRemoveBlock(.init(blocks: response.updatedBlocks,
                                          totalDurationMinutes: total))
    }

    func presentMoveBlock(_ response: ProgramEditorModels.MoveBlock.Response) async {
        display?.displayMoveBlock(.init(blocks: response.updatedBlocks))
    }

    func presentSaveProgram(_ response: ProgramEditorModels.SaveProgram.Response) async {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        let vm = ProgramEditorModels.SaveProgram.ViewModel(
            confirmationMessage: String(
                localized: "program.saved.at.\(formatter.string(from: response.savedAt))"
            )
        )
        display?.displaySaveProgram(vm)
    }

    // MARK: - Validation

    static func isValid(_ blocks: [ProgramBlock]) -> Bool {
        let total = blocks.map(\.durationMinutes).reduce(0, +)
        guard total > 0, total <= 30 else { return false }

        let hasProduction = blocks.contains {
            [.isolatedSound, .syllables, .wordsInitial, .wordsMedial, .wordsFinal, .phrases]
                .contains($0.type)
        }
        guard hasProduction else { return false }

        // No two break blocks in a row.
        for i in 1..<blocks.count where blocks[i].type == .breakRest
            && blocks[i - 1].type == .breakRest {
            return false
        }
        return true
    }
}
