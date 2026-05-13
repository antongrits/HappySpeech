import Foundation
import SwiftUI

// MARK: - DailyChallengeRoutingLogic

@MainActor
protocol DailyChallengeRoutingLogic: AnyObject {
    func dismiss()
    func routeToSession(childId: String, targetSound: String)
    func routeToShareSheet(snapshotText: String)
}

// MARK: - DailyChallengeRouter (Clean Swift: Router)
//
// Block AE batch 2 v21 — навигация ежедневного челленджа.
//
// Start CTA → запуск lessonPlayer (через AppCoordinator.navigate).
// Share CTA → системный ShareSheet через UIActivityViewController-обёртку.

@MainActor
final class DailyChallengeRouter: DailyChallengeRoutingLogic {

    var dismissAction: (() -> Void)?
    var startSessionAction: ((_ childId: String, _ targetSound: String) -> Void)?
    var shareAction: ((_ text: String) -> Void)?

    init(
        dismissAction: (() -> Void)? = nil,
        startSessionAction: ((String, String) -> Void)? = nil,
        shareAction: ((String) -> Void)? = nil
    ) {
        self.dismissAction = dismissAction
        self.startSessionAction = startSessionAction
        self.shareAction = shareAction
    }

    func dismiss() {
        dismissAction?()
    }

    func routeToSession(childId: String, targetSound: String) {
        startSessionAction?(childId, targetSound)
    }

    func routeToShareSheet(snapshotText: String) {
        shareAction?(snapshotText)
    }
}
