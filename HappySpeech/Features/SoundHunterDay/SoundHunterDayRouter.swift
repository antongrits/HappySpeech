import Foundation

// MARK: - SoundHunterDayRoutingLogic
//
// «Звуковой охотник дня» — самодостаточный экран (миссия дня + копилка/чек-ин),
// запускается из ChildHome (kid) или ParentHome (parent). Завершение возвращает
// в исходную главную.

@MainActor
protocol SoundHunterDayRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - SoundHunterDayRouter

@MainActor
final class SoundHunterDayRouter: SoundHunterDayRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
