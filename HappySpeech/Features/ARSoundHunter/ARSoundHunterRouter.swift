import SwiftUI

// MARK: - ARSoundHunterRoutingLogic

@MainActor
protocol ARSoundHunterRoutingLogic {
    func routeBack()
}

// MARK: - ARSoundHunterRouter

@MainActor
final class ARSoundHunterRouter: ARSoundHunterRoutingLogic {
    /// Закрывает экран — задаётся View через `@Environment(\.dismiss)`.
    var dismiss: (() -> Void)?

    func routeBack() { dismiss?() }
}
