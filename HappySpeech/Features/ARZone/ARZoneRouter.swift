import SwiftUI

// MARK: - ARZoneRoutingLogic

@MainActor
protocol ARZoneRoutingLogic {
    func routeBack()
    func routeToGame(_ destination: ARGameDestination)
    func routeToFallback()
}

// MARK: - ARZoneRouter

@MainActor
final class ARZoneRouter: ARZoneRoutingLogic {

    weak var coordinator: AppCoordinator?
    var onNavigateLocal: ((ARGameDestination) -> Void)?

    func routeBack() {
        coordinator?.pop()
    }

    func routeToGame(_ destination: ARGameDestination) {
        // Локальная навигация внутри NavigationStack'а ARZoneView
        // (coordinator не знает о конкретных AR-играх, т.к. они сгруппированы под arZone)
        onNavigateLocal?(destination)
    }

    /// Fallback для устройств без TrueDepth: возвращаем пользователя на предыдущий
    /// экран (обычно ChildHome или WorldMap), откуда он может выбрать обычные 2D-уроки.
    func routeToFallback() {
        coordinator?.pop()
    }
}
