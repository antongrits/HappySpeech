import Foundation

// MARK: - ProgramEditorPresentationLogic

@MainActor
protocol ProgramEditorPresentationLogic: AnyObject {
    func presentLoadProgram(_ response: ProgramEditorModels.LoadProgram.Response) async
    func presentAddBlock(_ response: ProgramEditorModels.AddBlock.Response) async
    func presentRemoveBlock(_ response: ProgramEditorModels.RemoveBlock.Response) async
    func presentMoveBlock(_ response: ProgramEditorModels.MoveBlock.Response) async
    func presentSaveProgram(_ response: ProgramEditorModels.SaveProgram.Response) async
    // D.1 v15
    func presentValidation(_ response: ProgramEditorModels.ValidateProgram.Response) async
    func presentValidationWarning(_ response: ProgramEditorModels.ValidationWarning.Response) async
    func presentAssignToChild(_ response: ProgramEditorModels.AssignToChild.Response) async
    // Import / Export
    func presentExportTemplate(_ response: ProgramEditorModels.ExportTemplate.Response) async
    func presentImportTemplate(_ response: ProgramEditorModels.ImportTemplate.Response) async
    func presentImportTemplateFailure(_ response: ProgramEditorModels.ImportTemplate.FailureViewModel) async
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
            isValid: Self.isValid(response.program.blocks),
            validationWarnings: response.validationWarnings
        )
        display?.displayLoadProgram(vm)
    }

    func presentAddBlock(_ response: ProgramEditorModels.AddBlock.Response) async {
        display?.displayAddBlock(.init(
            blocks: response.updatedBlocks,
            totalDurationMinutes: response.totalDurationMinutes,
            validationWarnings: response.validationWarnings
        ))
    }

    func presentRemoveBlock(_ response: ProgramEditorModels.RemoveBlock.Response) async {
        display?.displayRemoveBlock(.init(
            blocks: response.updatedBlocks,
            totalDurationMinutes: response.totalDurationMinutes
        ))
    }

    func presentMoveBlock(_ response: ProgramEditorModels.MoveBlock.Response) async {
        display?.displayMoveBlock(.init(blocks: response.updatedBlocks))
    }

    func presentSaveProgram(_ response: ProgramEditorModels.SaveProgram.Response) async {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        // Дата — аргумент формат-строки, НЕ часть ключа локализации. Раньше дата
        // интерполировалась в префикс ключа → `String(localized:)` не находил
        // такой ключ и возвращал сырую строку-ключ вместо «Сохранено в …».
        let vm = ProgramEditorModels.SaveProgram.ViewModel(
            confirmationMessage: String(
                format: String(
                    localized: "program.saved.at %@",
                    defaultValue: "Сохранено в %@"
                ),
                formatter.string(from: response.savedAt)
            )
        )
        display?.displaySaveProgram(vm)
    }

    // MARK: - D.1 v15 — новые методы

    func presentValidation(_ response: ProgramEditorModels.ValidateProgram.Response) async {
        let summary: String
        if response.isValid {
            summary = String(localized: "program_editor.validation.valid")
        } else {
            summary = response.errors.joined(separator: "\n")
        }
        display?.displayValidation(ProgramEditorModels.ValidateProgram.ViewModel(
            isValid: response.isValid,
            summary: summary,
            warnings: response.warnings,
            totalDurationMinutes: response.totalDurationMinutes
        ))
    }

    func presentValidationWarning(_ response: ProgramEditorModels.ValidationWarning.Response) async {
        display?.displayValidationWarning(response.message)
    }

    func presentAssignToChild(_ response: ProgramEditorModels.AssignToChild.Response) async {
        let message = response.success
            ? String(localized: "program_editor.assign.success")
            : response.errorMessage ?? String(localized: "program_editor.assign.failure")
        display?.displayAssignToChild(ProgramEditorModels.AssignToChild.ViewModel(
            success: response.success,
            message: message
        ))
    }

    // MARK: - Import / Export

    func presentExportTemplate(_ response: ProgramEditorModels.ExportTemplate.Response) async {
        display?.displayExportTemplate(.init(fileURL: response.fileURL))
    }

    func presentImportTemplate(_ response: ProgramEditorModels.ImportTemplate.Response) async {
        let total = response.program.blocks.map(\.durationMinutes).reduce(0, +)
        display?.displayImportTemplate(.init(
            blocks: response.program.blocks,
            totalDurationMinutes: total,
            validationWarnings: response.validationWarnings
        ))
    }

    func presentImportTemplateFailure(_ response: ProgramEditorModels.ImportTemplate.FailureViewModel) async {
        display?.displayImportTemplateFailure(response)
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
