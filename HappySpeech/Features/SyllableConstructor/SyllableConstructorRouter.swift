import Foundation

// MARK: - SyllableConstructorRoutingLogic

@MainActor
protocol SyllableConstructorRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - SyllableConstructorRouter (Clean Swift: Router)
//
// v31 Волна B, Функция Ф.1 «Слог-конструктор».

@MainActor
final class SyllableConstructorRouter: SyllableConstructorRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
