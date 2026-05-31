import Foundation

// MARK: - FourthExtraRoutingLogic

@MainActor
protocol FourthExtraRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - FourthExtraRouter (Clean Swift: Router)
//
// F2-005 «Четвёртый лишний» (Wave 2).
//
// Игра самодостаточна; завершение возвращает в детскую главную.

@MainActor
final class FourthExtraRouter: FourthExtraRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
