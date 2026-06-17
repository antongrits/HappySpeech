import Foundation

// MARK: - AdvancedGrammarRoutingLogic
//
// «Грамматический конструктор-2» — самодостаточная kid-игра, запускается из
// ChildHome как отдельный экран. Завершение возвращает в детскую главную.

@MainActor
protocol AdvancedGrammarRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - AdvancedGrammarRouter

@MainActor
final class AdvancedGrammarRouter: AdvancedGrammarRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
