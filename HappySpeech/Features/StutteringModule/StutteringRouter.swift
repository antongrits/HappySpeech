import Foundation
import SwiftUI

// MARK: - StutteringRouter

@MainActor
final class StutteringRouter {

    weak var coordinator: AppCoordinator?

    func routeToStutteringHome() {
        coordinator?.navigate(to: .stutteringHome)
    }

    func routeToFluencyDiaryParent() {
        coordinator?.navigate(to: .fluencyDiaryParent)
    }
}
