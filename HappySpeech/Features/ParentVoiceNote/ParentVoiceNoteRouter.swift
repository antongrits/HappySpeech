import Foundation

// MARK: - ParentVoiceNoteRoutingLogic

@MainActor
protocol ParentVoiceNoteRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - ParentVoiceNoteRouter (Clean Swift: Router)

@MainActor
final class ParentVoiceNoteRouter: ParentVoiceNoteRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
