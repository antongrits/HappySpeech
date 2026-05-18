import Foundation

// MARK: - RetellingRoutingLogic

@MainActor
protocol RetellingRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - RetellingRouter (Clean Swift: Router)
//
// v29 Фаза 8, Функция 2 «Расскажи по-настоящему».
//
// Игра самодостаточна; завершение возвращает в детскую главную.

@MainActor
final class RetellingRouter: RetellingRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
