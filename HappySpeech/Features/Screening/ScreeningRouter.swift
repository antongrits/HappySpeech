import Foundation

// MARK: - ScreeningRouter

/// Navigation glue for Screening. In the app today the screening is presented
/// as a modal sheet over ParentHome; after finish, the router fires
/// `onComplete(outcome)` so the parent flow can persist the verdict into the
/// child profile and update the adaptive planner.
@MainActor
final class ScreeningRouter {

    /// Fired when the screening completes successfully. The caller is expected
    /// to persist `ScreeningOutcome` to the child profile and dismiss the
    /// screening sheet.
    var onComplete: ((ScreeningOutcome) -> Void)?
    /// Fired when the user aborts mid-screening.
    var onCancel: (() -> Void)?

    func complete(outcome: ScreeningOutcome) {
        onComplete?(outcome)
    }

    func cancel() {
        onCancel?()
    }
}
