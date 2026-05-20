import SwiftUI

// MARK: - LetterTraceRoutingLogic

@MainActor
protocol LetterTraceRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - LetterTraceRouter (Clean Swift: Router)
//
// v31 Волна C Ф.2. Экран открывается из ChildHome модальным push'ем
// в основном стеке (AppCoordinator route) и закрывается стандартным
// dismiss — нет вложенной навигации.

@MainActor
final class LetterTraceRouter: LetterTraceRoutingLogic {

    private let dismissAction: () -> Void

    init(dismissAction: @escaping () -> Void) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction()
    }
}
