import Foundation

// MARK: - SpeechTempoRoutingLogic

@MainActor
protocol SpeechTempoRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - SpeechTempoRouter (Clean Swift: Router)
//
// v29 Фаза 8, Функция 6 «Темп-дорожка».
//
// Игра самодостаточна; завершение возвращает в детскую главную.

@MainActor
final class SpeechTempoRouter: SpeechTempoRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
