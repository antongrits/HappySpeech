import Foundation

// MARK: - LiveSoundsRoutingLogic
//
// «Живые звуки» — самодостаточная kid-игра, запускается из ChildHome как
// отдельный экран. Завершение возвращает в детскую главную.

@MainActor
protocol LiveSoundsRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - LiveSoundsRouter

@MainActor
final class LiveSoundsRouter: LiveSoundsRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
