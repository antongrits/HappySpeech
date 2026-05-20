import SwiftUI

@MainActor
final class DailyTimeCapRouter {

    weak var coordinator: AppCoordinator?

    func dismiss() {
        coordinator?.navigate(to: .parentHome)
    }
}
