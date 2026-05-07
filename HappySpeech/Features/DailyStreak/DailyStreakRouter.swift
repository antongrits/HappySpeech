import Foundation
import SwiftUI

// MARK: - DailyStreakRoutingLogic

@MainActor
protocol DailyStreakRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - DailyStreakRouter (Clean Swift: Router)
//
// Block S.1 v16 — простая навигация: фича модальная (sheet), управляется
// родителем через @Binding/dismiss.

@MainActor
final class DailyStreakRouter: DailyStreakRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
