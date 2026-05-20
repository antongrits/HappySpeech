import Foundation

// MARK: - ComprehensionDetectiveRoutingLogic

@MainActor
protocol ComprehensionDetectiveRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - ComprehensionDetectiveRouter (Clean Swift: Router)
//
// v31 Волна B, Функция Ф.2 «Понимание-детектив».

@MainActor
final class ComprehensionDetectiveRouter: ComprehensionDetectiveRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
