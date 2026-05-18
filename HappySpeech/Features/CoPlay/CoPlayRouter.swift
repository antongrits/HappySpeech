import Foundation

// MARK: - CoPlayRoutingLogic

@MainActor
protocol CoPlayRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - CoPlayRouter (Clean Swift: Router)
//
// v29 Фаза 8, Функция 8 «Занятие вместе».
//
// Игра самодостаточна; завершение возвращает в детскую главную.

@MainActor
final class CoPlayRouter: CoPlayRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
