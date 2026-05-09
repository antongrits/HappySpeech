import Foundation
import SwiftUI

// MARK: - DialectAdaptationRoutingLogic

@MainActor
protocol DialectAdaptationRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - DialectAdaptationRouter (Clean Swift: Router)
//
// Block R.1 v18 — модальная навигация (sheet), управляется родителем
// через `dismissAction`. Не использует AppCoordinator — не нужно,
// т.к. экран самодостаточен (не открывает деталей).

@MainActor
final class DialectAdaptationRouter: DialectAdaptationRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
