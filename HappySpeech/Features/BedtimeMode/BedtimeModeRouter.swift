import Foundation

// MARK: - BedtimeModeRoutingLogic

@MainActor
protocol BedtimeModeRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - BedtimeModeRouter (Clean Swift: Router)
//
// v31 Волна B, Функция Ф.3 «Bedtime mode».

@MainActor
final class BedtimeModeRouter: BedtimeModeRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
