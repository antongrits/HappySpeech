import Foundation
import SwiftUI

// MARK: - FamilyAchievementsRoutingLogic

@MainActor
protocol FamilyAchievementsRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - FamilyAchievementsRouter (Clean Swift: Router)
//
// Block R.4 v18 — модальная навигация (sheet), без подмаршрутов.

@MainActor
final class FamilyAchievementsRouter: FamilyAchievementsRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
