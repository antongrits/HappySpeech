import SwiftUI

// MARK: - AchievementsRoutingLogic

@MainActor
protocol AchievementsRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - AchievementsRouter

@MainActor
final class AchievementsRouter: AchievementsRoutingLogic {

    weak var coordinator: AppCoordinator?

    func dismiss() {
        coordinator?.pop()
    }
}
