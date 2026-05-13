import Foundation
import SwiftUI

// MARK: - FamilyAwardsCabinetRoutingLogic

@MainActor
protocol FamilyAwardsCabinetRoutingLogic: AnyObject {
    func dismiss()
    func routeToChildAchievements(childId: String)
}

// MARK: - FamilyAwardsCabinetRouter (Clean Swift: Router)
//
// Block AE batch 2 v21 — детали награды — sheet внутри экрана,
// открытие полного экрана достижений ребёнка — через callback.

@MainActor
final class FamilyAwardsCabinetRouter: FamilyAwardsCabinetRoutingLogic {

    var dismissAction: (() -> Void)?
    var openAchievementsAction: ((String) -> Void)?

    init(
        dismissAction: (() -> Void)? = nil,
        openAchievementsAction: ((String) -> Void)? = nil
    ) {
        self.dismissAction = dismissAction
        self.openAchievementsAction = openAchievementsAction
    }

    func dismiss() {
        dismissAction?()
    }

    func routeToChildAchievements(childId: String) {
        openAchievementsAction?(childId)
    }
}
