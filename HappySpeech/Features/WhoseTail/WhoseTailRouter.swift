import Foundation

// MARK: - WhoseTailRoutingLogic

@MainActor
protocol WhoseTailRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - WhoseTailRouter (Clean Swift: Router)
//
// F2-006 «Чей хвост / чей домик» (Wave 2).
//
// Игра самодостаточна; завершение возвращает в детскую главную.

@MainActor
final class WhoseTailRouter: WhoseTailRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
