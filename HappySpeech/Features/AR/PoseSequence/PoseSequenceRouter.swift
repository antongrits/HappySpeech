import SwiftUI

@MainActor
protocol PoseSequenceRoutingLogic {
    func routeBack()
}

@MainActor
final class PoseSequenceRouter: PoseSequenceRoutingLogic {
    var dismiss: (() -> Void)?
    func routeBack() { dismiss?() }
}
