import Foundation
import SwiftUI

// MARK: - CustomizationRoutingLogic

@MainActor
protocol CustomizationRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - CustomizationRouter

@MainActor
final class CustomizationRouter: CustomizationRoutingLogic {

    weak var viewController: (AnyObject & CustomizationRoutingLogic)?
    private let dismissAction: () -> Void

    init(dismissAction: @escaping () -> Void) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction()
    }
}
