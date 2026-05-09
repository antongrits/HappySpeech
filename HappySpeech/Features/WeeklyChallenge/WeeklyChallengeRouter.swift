import Foundation
import SwiftUI

// MARK: - WeeklyChallengeRoutingLogic

@MainActor
protocol WeeklyChallengeRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - WeeklyChallengeRouter (Clean Swift: Router)
//
// Block R.3 v18 — модальная навигация (sheet), управляется родителем
// через `dismissAction`. Внутренний выбор kind не требует отдельной
// навигации — всё в текущем экране через segmented picker.

@MainActor
final class WeeklyChallengeRouter: WeeklyChallengeRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
