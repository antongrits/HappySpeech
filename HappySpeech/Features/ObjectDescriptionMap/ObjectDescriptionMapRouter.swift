import SwiftUI

// MARK: - ObjectDescriptionMapRouter

/// VIP-Router. Сейчас задача — только закрыть экран (`coordinator?.pop()`).
/// Оставлен отдельным типом для будущих расширений (например, переход в
/// родительский диалог-разбор после результата).
@MainActor
final class ObjectDescriptionMapRouter {

    weak var coordinator: AppCoordinator?

    func dismiss() {
        coordinator?.pop()
    }
}
