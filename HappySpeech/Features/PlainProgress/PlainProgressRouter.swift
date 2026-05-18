import Foundation

// MARK: - PlainProgressRoutingLogic

@MainActor
protocol PlainProgressRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - PlainProgressRouter (Clean Swift: Router)
//
// v29 Фаза 8, Функция 9 «Понятный прогресс».
//
// Экран самодостаточен (один уровень). Поделиться сводкой обрабатывается
// внутри View системным `ShareLink` — внешней навигации не требуется.

@MainActor
final class PlainProgressRouter: PlainProgressRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
