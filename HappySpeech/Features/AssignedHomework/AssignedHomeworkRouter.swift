import Foundation

// MARK: - AssignedHomeworkRoutingLogic

@MainActor
protocol AssignedHomeworkRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - AssignedHomeworkRouter (Clean Swift: Router)
//
// v29 Фаза 8, Функция 4 «Домашнее задание от логопеда».
//
// Экран самодостаточен; завершение возвращает в специалистский контур.

@MainActor
final class AssignedHomeworkRouter: AssignedHomeworkRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
