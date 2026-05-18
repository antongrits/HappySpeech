import Foundation

// MARK: - ParentGuideRoutingLogic

@MainActor
protocol ParentGuideRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - ParentGuideRouter (Clean Swift: Router)
//
// v29 Фаза 8, Функция 3 «Логопед для родителей».
//
// Детали урока показываются inline в sheet — внешней навигации не требуется.

@MainActor
final class ParentGuideRouter: ParentGuideRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
