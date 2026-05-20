import SwiftUI

@MainActor
final class SpeechGrowthDiaryRouter {

    weak var coordinator: AppCoordinator?

    func dismiss() {
        coordinator?.pop()
    }

    /// Если родитель не давал разрешение на камеру — открыть PermissionFlow.
    func openCameraPermissionFlow() {
        coordinator?.navigate(to: .permissionFlow(.camera))
    }
}
