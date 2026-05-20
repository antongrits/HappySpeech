import SwiftUI

// MARK: - LogorhythmicsRouter

/// VIP-Router. Сейчас задача — только закрыть экран (`coordinator?.pop()`).
/// Оставлен отдельным типом для будущих расширений (например, переход
/// в SessionComplete после Realm-интеграции в следующей волне).
@MainActor
final class LogorhythmicsRouter {

    weak var coordinator: AppCoordinator?

    func dismiss() {
        coordinator?.pop()
    }
}
