import Foundation
import SwiftUI

// MARK: - FamilyLeaderboardRoutingLogic

@MainActor
protocol FamilyLeaderboardRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - FamilyLeaderboardRouter

@MainActor
final class FamilyLeaderboardRouter: FamilyLeaderboardRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
