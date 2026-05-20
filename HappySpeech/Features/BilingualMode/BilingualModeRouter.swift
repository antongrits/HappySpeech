import SwiftUI

// MARK: - BilingualModeRouter
//
// VIP-Router. Сейчас задача — только закрыть экран. Оставлен отдельным
// типом для возможных будущих расширений (например, переход в
// родительский диалог с обзором словаря).

@MainActor
final class BilingualModeRouter {

    weak var coordinator: AppCoordinator?

    func dismiss() {
        coordinator?.pop()
    }
}
