import SwiftUI

@MainActor
protocol ARMirrorRoutingLogic {
    func routeBack()
}

@MainActor
final class ARMirrorRouter: ARMirrorRoutingLogic {

    weak var coordinator: AppCoordinator?
    var dismiss: (() -> Void)?

    func routeBack() {
        dismiss?()
    }
}
