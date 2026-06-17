import Foundation

// MARK: - VoiceStrongmanRoutingLogic
//
// «Силач-голос» — самодостаточная kid-игра, запускается из ChildHome как
// отдельный экран. Завершение возвращает в детскую главную.

@MainActor
protocol VoiceStrongmanRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - VoiceStrongmanRouter

@MainActor
final class VoiceStrongmanRouter: VoiceStrongmanRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
