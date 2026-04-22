import SwiftUI

@MainActor
protocol HoldThePoseRoutingLogic {
    func routeBack()
}

@MainActor
final class HoldThePoseRouter: HoldThePoseRoutingLogic {
    var dismiss: (() -> Void)?
    func routeBack() { dismiss?() }
}
