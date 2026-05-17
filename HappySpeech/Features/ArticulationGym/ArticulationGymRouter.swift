import Foundation
import SwiftUI

// MARK: - ArticulationGymRoutingLogic

@MainActor
protocol ArticulationGymRoutingLogic: AnyObject {
    func routeToWorldMap()
    func dismiss()
}

// MARK: - ArticulationGymRouter (Clean Swift: Router)
//
// F-302 v25 — навигация.
//   • routeToWorldMap — кнопка «Начать урок» на завершающем экране.
//   • dismiss — кнопка «✕» в навигации.

@MainActor
final class ArticulationGymRouter: ArticulationGymRoutingLogic {

    private weak var coordinator: AppCoordinator?
    private let childId: String
    private let dismissAction: () -> Void

    init(
        coordinator: AppCoordinator?,
        childId: String,
        dismissAction: @escaping () -> Void
    ) {
        self.coordinator = coordinator
        self.childId = childId
        self.dismissAction = dismissAction
    }

    func routeToWorldMap() {
        guard let coordinator else {
            dismissAction()
            return
        }
        coordinator.navigate(to: .worldMap(childId: childId, targetSound: "С"))
    }

    func dismiss() {
        dismissAction()
    }
}
