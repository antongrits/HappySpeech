import Foundation

// MARK: - DailyRitualsLyalyaRoutingLogic

@MainActor
protocol DailyRitualsLyalyaRoutingLogic: AnyObject {
    func dismiss()
}

@MainActor
final class DailyRitualsLyalyaRouter: DailyRitualsLyalyaRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
