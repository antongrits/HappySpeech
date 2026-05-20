import Foundation

// MARK: - ReadAloudStoryRoutingLogic

@MainActor
protocol ReadAloudStoryRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - ReadAloudStoryRouter
//
// v31 Волна D Ф.1 — самодостаточная фича, по завершении возвращает на
// ChildHome через `dismissAction`.

@MainActor
final class ReadAloudStoryRouter: ReadAloudStoryRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
