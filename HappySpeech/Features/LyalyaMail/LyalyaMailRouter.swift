import SwiftUI

// MARK: - LyalyaMailRouter

/// Минимальный VIP-Router: только закрытие экрана.
/// Открытие detail-sheet делает сама View через `@State`.
@MainActor
final class LyalyaMailRouter {

    weak var coordinator: AppCoordinator?

    func dismiss() {
        coordinator?.pop()
    }
}
