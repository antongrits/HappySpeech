import Foundation

// MARK: - VoicingSoftnessRoutingLogic

@MainActor
protocol VoicingSoftnessRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - VoicingSoftnessRouter (Clean Swift: Router)
//
// «Карта звонкости и мягкости». Игра самодостаточна; завершение возвращает
// в детскую главную через переданное действие закрытия.

@MainActor
final class VoicingSoftnessRouter: VoicingSoftnessRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
