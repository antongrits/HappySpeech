import Foundation

// MARK: - StoryPicturesRoutingLogic
//
// «Рассказ по серии картинок» — самодостаточная kid-игра, запускается из
// ChildHome как отдельный экран. Завершение возвращает в детскую главную.

@MainActor
protocol StoryPicturesRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - StoryPicturesRouter

@MainActor
final class StoryPicturesRouter: StoryPicturesRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
