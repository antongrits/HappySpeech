import SwiftUI

// MARK: - RhythmRoutingLogic

@MainActor
protocol RhythmRoutingLogic {
    func routeToSessionComplete()
    func routeBack()
}

// MARK: - RhythmRouter
//
// Rhythm-игра завёрнута в SessionShell, поэтому роутер используется
// только при прямом переходе к экрану из диплинка / Demo-меню. В основном
// потоке завершение игры отдаётся через `onComplete(Float)`, а SessionShell
// решает, куда идти дальше.

@MainActor
final class RhythmRouter: RhythmRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeToSessionComplete() {
        coordinator?.navigate(to: .sessionComplete)
    }

    func routeBack() {
        coordinator?.pop()
    }
}
