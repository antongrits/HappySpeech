import Foundation

// MARK: - ProgramEditorDisplayLogic

@MainActor
protocol ProgramEditorDisplayLogic: AnyObject {
    func displayLoadProgram(_ viewModel: ProgramEditorModels.LoadProgram.ViewModel)
    func displayAddBlock(_ viewModel: ProgramEditorModels.AddBlock.ViewModel)
    func displayRemoveBlock(_ viewModel: ProgramEditorModels.RemoveBlock.ViewModel)
    func displayMoveBlock(_ viewModel: ProgramEditorModels.MoveBlock.ViewModel)
    func displaySaveProgram(_ viewModel: ProgramEditorModels.SaveProgram.ViewModel)
    // D.1 v15
    func displayValidation(_ viewModel: ProgramEditorModels.ValidateProgram.ViewModel)
    func displayValidationWarning(_ message: String)
    func displayAssignToChild(_ viewModel: ProgramEditorModels.AssignToChild.ViewModel)
}

// Note: ValidateProgram and AssignToChild ViewModels are defined inside
// the enum extensions in ProgramEditorInteractor.swift (D.1 v15).
