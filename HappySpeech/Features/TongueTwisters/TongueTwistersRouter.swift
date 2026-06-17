import Foundation

// MARK: - TongueTwistersRoutingLogic
//
// «Чистоговорки-конструктор» — самодостаточная kid-игра, запускается из
// ChildHome как отдельный экран. Завершение возвращает в детскую главную.

@MainActor
protocol TongueTwistersRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - TongueTwistersRouter

@MainActor
final class TongueTwistersRouter: TongueTwistersRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
