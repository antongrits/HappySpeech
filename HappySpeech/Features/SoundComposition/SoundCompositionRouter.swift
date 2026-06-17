import Foundation

// MARK: - SoundCompositionRoutingLogic
//
// «Мастерская звукового состава» — самодостаточная kid-игра, запускается из
// ChildHome как отдельный экран. Завершение возвращает в детскую главную.

@MainActor
protocol SoundCompositionRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - SoundCompositionRouter

@MainActor
final class SoundCompositionRouter: SoundCompositionRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
