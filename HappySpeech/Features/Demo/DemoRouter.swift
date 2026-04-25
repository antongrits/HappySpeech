import SwiftUI

// MARK: - DemoRoutingLogic

@MainActor
protocol DemoRoutingLogic {
    func routeSkipped()
    func routeCompleted()
}

// MARK: - DemoRouter
//
// View задаёт колбэки: вызывается, когда пользователь нажал «Пропустить»
// или прошёл все 15 шагов. Default behaviour — pop из координатора.

@MainActor
final class DemoRouter: DemoRoutingLogic {

    var onSkipped: (() -> Void)?
    var onCompleted: (() -> Void)?

    func routeSkipped() { onSkipped?() }
    func routeCompleted() { onCompleted?() }
}
