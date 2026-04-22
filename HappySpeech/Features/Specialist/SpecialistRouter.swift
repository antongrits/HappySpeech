import SwiftUI

// MARK: - SpecialistRoutingLogic

@MainActor
protocol SpecialistRoutingLogic {
    func routeBack()
}

// MARK: - SpecialistRouter

@MainActor
final class SpecialistRouter: SpecialistRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeBack() {
        coordinator?.pop()
    }
}
