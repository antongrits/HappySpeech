import Foundation
import SwiftUI

// MARK: - ParentInsightsTimelineRoutingLogic

@MainActor
protocol ParentInsightsTimelineRoutingLogic: AnyObject {
    func dismiss()
    func routeToProgressDashboard()
}

// MARK: - ParentInsightsTimelineRouter (Clean Swift: Router)
//
// Block AE batch 2 v21 — детали дня показываются sheet'ом внутри экрана,
// глубокая аналитика — переход в ProgressDashboardView через callback.

@MainActor
final class ParentInsightsTimelineRouter: ParentInsightsTimelineRoutingLogic {

    var dismissAction: (() -> Void)?
    var openProgressDashboardAction: (() -> Void)?

    init(
        dismissAction: (() -> Void)? = nil,
        openProgressDashboardAction: (() -> Void)? = nil
    ) {
        self.dismissAction = dismissAction
        self.openProgressDashboardAction = openProgressDashboardAction
    }

    func dismiss() {
        dismissAction?()
    }

    func routeToProgressDashboard() {
        openProgressDashboardAction?()
    }
}
