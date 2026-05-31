import Foundation

// MARK: - WordFormationRoutingLogic

@MainActor
protocol WordFormationRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - WordFormationRouter (Clean Swift: Router)
//
// F2-007 «Назови ласково / Один-много-нет» (Wave 2).
//
// Игра самодостаточна; завершение возвращает в детскую главную.

@MainActor
final class WordFormationRouter: WordFormationRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
