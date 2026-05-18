import Foundation

// MARK: - BreatheAndSpeakRoutingLogic

@MainActor
protocol BreatheAndSpeakRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - BreatheAndSpeakRouter (Clean Swift: Router)
//
// v29 Фаза 8, Функция 10 «Дыши и говори».
//
// Комплекс самодостаточен; завершение возвращает в детскую главную.

@MainActor
final class BreatheAndSpeakRouter: BreatheAndSpeakRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
