import SwiftUI

// MARK: - ProfileEditorRouter

@MainActor
final class ProfileEditorRouter {
    private weak var coordinator: AppCoordinator?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    func dismiss() {
        coordinator?.dismissSheet()
    }
}
