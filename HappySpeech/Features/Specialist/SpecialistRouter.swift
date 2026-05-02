import OSLog
import SwiftUI

// MARK: - SpecialistRoutingLogic

@MainActor
protocol SpecialistRoutingLogic: AnyObject {
    func routeBack()
    func routeToSessionReview(sessionId: String)
    func routeToChildDashboard(childId: String)
    func routeToProgramEditor(childId: String)
}

// MARK: - SpecialistRouter

/// Роутер специалистского контура. Управляет переходами между:
/// - caseload (список детей)
/// - child dashboard
/// - session review
/// - program editor
///
/// Навигация через NavigationStack — колбэки инициируют push в view-слое.
@MainActor
final class SpecialistRouter: SpecialistRoutingLogic {

    weak var coordinator: AppCoordinator?

    var onOpenSessionReview: ((String) -> Void)?
    var onOpenChildDashboard: ((String) -> Void)?
    var onOpenProgramEditor: ((String) -> Void)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Specialist.Router")

    // MARK: - Routing

    func routeBack() {
        coordinator?.pop()
    }

    func routeToSessionReview(sessionId: String) {
        guard !sessionId.isEmpty else {
            logger.warning("routeToSessionReview: empty sessionId — skip")
            return
        }
        if let handler = onOpenSessionReview {
            handler(sessionId)
        } else {
            logger.warning("routeToSessionReview: callback not wired (sessionId=\(sessionId, privacy: .public))")
        }
    }

    func routeToChildDashboard(childId: String) {
        guard !childId.isEmpty else {
            logger.warning("routeToChildDashboard: empty childId — skip")
            return
        }
        if let handler = onOpenChildDashboard {
            handler(childId)
        } else {
            logger.warning("routeToChildDashboard: callback not wired (childId=\(childId, privacy: .public))")
        }
    }

    func routeToProgramEditor(childId: String) {
        guard !childId.isEmpty else {
            logger.warning("routeToProgramEditor: empty childId — skip")
            return
        }
        if let handler = onOpenProgramEditor {
            handler(childId)
        } else {
            logger.warning("routeToProgramEditor: callback not wired (childId=\(childId, privacy: .public))")
        }
    }
}
