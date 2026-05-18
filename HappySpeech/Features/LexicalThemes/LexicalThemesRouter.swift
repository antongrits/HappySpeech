import Foundation

// MARK: - LexicalThemesRoutingLogic

@MainActor
protocol LexicalThemesRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - LexicalThemesRouter (Clean Swift: Router)
//
// v29 Фаза 8, Функция 7 «Мир слов».
//
// Хаб самодостаточен; завершение возвращает в детскую главную.

@MainActor
final class LexicalThemesRouter: LexicalThemesRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
