import SwiftUI

// MARK: - FingerPlayRouter

@MainActor
final class FingerPlayRouter {

    weak var coordinator: AppCoordinator?

    func dismiss() {
        coordinator?.pop()
    }

    /// При отказе в разрешении на камеру — отправляем родителя/ребёнка
    /// на PermissionFlowView (parent-circuit, parental gate).
    func openCameraPermissionFlow() {
        coordinator?.navigate(to: .permissionFlow(.camera))
    }
}
