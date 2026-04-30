import Foundation
import SwiftUI

// MARK: - SharePlayRoutingLogic

@MainActor
protocol SharePlayRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - SharePlayRouter

/// Маршрутизатор модуля SharePlay.
/// Закрывает шторку / возвращает в FamilyHome через AppCoordinator.

@MainActor
final class SharePlayRouter: SharePlayRoutingLogic {

    private weak var coordinator: AppCoordinator?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    func dismiss() {
        coordinator?.navigate(to: .familyHome)
    }
}
