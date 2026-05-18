import Foundation

// MARK: - SoundTrafficLightRoutingLogic

@MainActor
protocol SoundTrafficLightRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - SoundTrafficLightRouter (Clean Swift: Router)
//
// v29 Фаза 8, Функция 5 «Звуковой светофор».
//
// Игра самодостаточна; завершение возвращает в детскую главную.

@MainActor
final class SoundTrafficLightRouter: SoundTrafficLightRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
