import SwiftUI

// MARK: - SettingsRoutingLogic

@MainActor
protocol SettingsRoutingLogic {
    func routeBack()
}

// MARK: - SettingsRouter

@MainActor
final class SettingsRouter: SettingsRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeBack() {
        coordinator?.pop()
    }
}
