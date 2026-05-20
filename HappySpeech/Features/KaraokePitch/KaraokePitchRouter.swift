import SwiftUI

// MARK: - KaraokePitchRouter
//
// Тонкий Router — обработка только закрытия экрана. Никаких глобальных
// маршрутов из караоке-сессии (это самодостаточный экран).

@MainActor
final class KaraokePitchRouter {

    weak var coordinator: AppCoordinator?

    func dismiss() {
        // Координатор сам решает, куда возвращать: реально — на childHome.
        coordinator?.pop()
    }
}
