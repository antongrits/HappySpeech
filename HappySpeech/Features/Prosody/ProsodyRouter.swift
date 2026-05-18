import Foundation

// MARK: - ProsodyRoutingLogic

@MainActor
protocol ProsodyRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - ProsodyRouter (Clean Swift: Router)
//
// v29 Фаза 8, Функция 1 «Голосовые краски».
//
// Игра самодостаточна; завершение возвращает в детскую главную.

@MainActor
final class ProsodyRouter: ProsodyRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
