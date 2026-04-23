import SwiftUI

@MainActor
protocol MimicLyalyaRoutingLogic {
    func routeBack()
}

@MainActor
final class MimicLyalyaRouter: MimicLyalyaRoutingLogic {
    var dismiss: (() -> Void)?
    func routeBack() { dismiss?() }
}
