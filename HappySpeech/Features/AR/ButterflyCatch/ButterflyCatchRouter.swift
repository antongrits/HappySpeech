import SwiftUI

@MainActor
protocol ButterflyCatchRoutingLogic {
    func routeBack()
}

@MainActor
final class ButterflyCatchRouter: ButterflyCatchRoutingLogic {
    var dismiss: (() -> Void)?
    func routeBack() { dismiss?() }
}
