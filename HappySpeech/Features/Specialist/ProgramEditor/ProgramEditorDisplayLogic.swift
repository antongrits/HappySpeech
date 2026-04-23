import Foundation

// MARK: - ProgramEditorDisplayLogic

@MainActor
protocol ProgramEditorDisplayLogic: AnyObject {
    func displayLoadProgram(_ viewModel: ProgramEditorModels.LoadProgram.ViewModel)
    func displayAddBlock(_ viewModel: ProgramEditorModels.AddBlock.ViewModel)
    func displayRemoveBlock(_ viewModel: ProgramEditorModels.RemoveBlock.ViewModel)
    func displayMoveBlock(_ viewModel: ProgramEditorModels.MoveBlock.ViewModel)
    func displaySaveProgram(_ viewModel: ProgramEditorModels.SaveProgram.ViewModel)
}
