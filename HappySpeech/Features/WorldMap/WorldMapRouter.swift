import SwiftUI

// MARK: - WorldMapRoutingLogic

@MainActor
protocol WorldMapRoutingLogic {
    func routeBack()
    func routeOpenZone(zoneId: String)
}

// MARK: - WorldMapRouter
//
// Лёгкий router без AppCoordinator-ссылки. View-уровень сам решает, как
// обрабатывать колбэки (например, push новой страницы или dismiss).

@MainActor
final class WorldMapRouter: WorldMapRoutingLogic {

    var onDismiss: (() -> Void)?
    var onOpenZone: ((String) -> Void)?

    func routeBack() {
        onDismiss?()
    }

    func routeOpenZone(zoneId: String) {
        onOpenZone?(zoneId)
    }
}
