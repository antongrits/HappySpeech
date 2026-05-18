import Foundation

// MARK: - StorytellingRoutingLogic

@MainActor
protocol StorytellingRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - StorytellingRouter (Clean Swift: Router)
//
// v29 Фаза 8, Функция 11 «Я расскажу историю».
//
// Игра самодостаточна; завершение возвращает в детскую главную.

@MainActor
final class StorytellingRouter: StorytellingRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
