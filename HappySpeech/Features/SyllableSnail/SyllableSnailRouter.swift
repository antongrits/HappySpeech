import Foundation

// MARK: - SyllableSnailRoutingLogic

@MainActor
protocol SyllableSnailRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - SyllableSnailRouter (Clean Swift: Router)
//
// F2-003 «Слоговая улитка» (Wave 2).
//
// Игра самодостаточна; завершение возвращает в детскую главную.

@MainActor
final class SyllableSnailRouter: SyllableSnailRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
