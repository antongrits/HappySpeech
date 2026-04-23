import SwiftUI

@MainActor
protocol SoundAndFaceRoutingLogic {
    func routeBack()
}

@MainActor
final class SoundAndFaceRouter: SoundAndFaceRoutingLogic {
    var dismiss: (() -> Void)?
    func routeBack() { dismiss?() }
}
