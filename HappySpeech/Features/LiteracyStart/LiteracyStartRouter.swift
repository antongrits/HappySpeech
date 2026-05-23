import SwiftUI

// MARK: - LiteracyStartRouter

/// VIP-Router. Передаёт навигационные намерения наружу — в AppCoordinator.
@MainActor
final class LiteracyStartRouter {

    weak var coordinator: AppCoordinator?

    /// Закрыть экран (возврат в ChildHome).
    func dismiss() {
        coordinator?.pop()
    }

    /// Перейти к экрану прописей с выбранной буквой.
    /// `letterTrace` уже зарегистрирован в `AppRoute`.
    func routeToLetterTrace(childId: String) {
        coordinator?.navigate(to: .letterTrace(childId: childId))
    }
}
