import Foundation

// MARK: - SentenceBuilderRoutingLogic

@MainActor
protocol SentenceBuilderRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - SentenceBuilderRouter (Clean Swift: Router)
//
// F2-004 «Конструктор предложения» (Wave 2).
//
// Игра самодостаточна; завершение возвращает в детскую главную.

@MainActor
final class SentenceBuilderRouter: SentenceBuilderRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
