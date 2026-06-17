import Foundation

// MARK: - VoiceColorsRoutingLogic
//
// «Голосовые краски» — самодостаточная kid-игра, запускается из ChildHome как
// отдельный экран. Завершение возвращает в детскую главную.

@MainActor
protocol VoiceColorsRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - VoiceColorsRouter

@MainActor
final class VoiceColorsRouter: VoiceColorsRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
