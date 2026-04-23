import Foundation

// MARK: - ProgramEditorRouter

@MainActor
final class ProgramEditorRouter {
    /// Fired when the specialist saves the program; caller persists via
    /// `AdaptivePlannerService.pinDailyProgram(childId:blocks:)`.
    var onSaved: ((Program) -> Void)?
    var onCancel: (() -> Void)?

    func finish(savedProgram program: Program) { onSaved?(program) }
    func cancel() { onCancel?() }
}
