import SwiftUI

// MARK: - MinimalPairsRoutingLogic
//
// Минимальный роутер — экран всегда возвращается к SessionShell через
// замыкание `onComplete(score)`. Отдельный роутер оставлен для соответствия
// Clean Swift VIP и будущего расширения (например, exit-confirm sheet).

@MainActor
protocol MinimalPairsRoutingLogic: AnyObject {
    func routeToSessionComplete()
    func routeBack()
}

@MainActor
final class MinimalPairsRouter: MinimalPairsRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeToSessionComplete() {
        coordinator?.navigate(to: .sessionComplete)
    }

    func routeBack() {
        coordinator?.pop()
    }
}
