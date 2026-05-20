import SwiftUI

// MARK: - CustomWordListRoutingLogic

@MainActor
protocol CustomWordListRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - CustomWordListRouter (Clean Swift: Router)
//
// v31 Волна C Ф.4. Открывается из специалиста (SpecialistReportsView footer
// или Reports tab card). Editor — это локальный sheet внутри основного
// экрана, поэтому Router отвечает только за выход на корневую вкладку.

@MainActor
final class CustomWordListRouter: CustomWordListRoutingLogic {

    private let dismissAction: () -> Void

    init(dismissAction: @escaping () -> Void) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction()
    }
}
