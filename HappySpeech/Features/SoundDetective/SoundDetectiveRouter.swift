import Foundation

// MARK: - SoundDetectiveRoutingLogic

@MainActor
protocol SoundDetectiveRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - SoundDetectiveRouter (Clean Swift: Router)
//
// F2-009 «Звуковой детектив» (Wave 2).
//
// Игра самодостаточна; завершение возвращает в детскую главную.

@MainActor
final class SoundDetectiveRouter: SoundDetectiveRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
