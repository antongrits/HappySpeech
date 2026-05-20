import SwiftUI

@MainActor
final class OralStoryCreatorRouter {

    weak var coordinator: AppCoordinator?

    func dismiss() {
        coordinator?.pop()
    }
}
