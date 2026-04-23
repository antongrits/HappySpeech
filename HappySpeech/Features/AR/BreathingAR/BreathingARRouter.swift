import SwiftUI

@MainActor
protocol BreathingARRoutingLogic {
    func routeBack()
}

@MainActor
final class BreathingARRouter: BreathingARRoutingLogic {
    var dismiss: (() -> Void)?
    func routeBack() { dismiss?() }
}
