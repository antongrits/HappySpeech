import Foundation

// MARK: - PhonemicListeningRoutingLogic

@MainActor
protocol PhonemicListeningRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - PhonemicListeningRouter (Clean Swift: Router)
//
// v29 Фаза 8, Функция 12 «Слушай внимательно».
//
// Игра самодостаточна; завершение возвращает в детскую главную.

@MainActor
final class PhonemicListeningRouter: PhonemicListeningRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
