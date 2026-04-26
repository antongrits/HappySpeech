import OSLog
import SwiftUI

// MARK: - SpecialistRoutingLogic

@MainActor
protocol SpecialistRoutingLogic: AnyObject {
    func routeBack()
    /// Открыть экран детального обзора сессии (B1).
    /// Используется из списка занятий, чтобы перейти на `SessionReviewView`.
    func routeToSessionReview(sessionId: String)
}

// MARK: - SpecialistRouter

/// Роутер специалистского контура. Контролирует переходы между списком детей,
/// детальной страницей сессии и отчётами. В Specialist-флоу навигация идёт
/// через `NavigationStack` (см. `SpecSessionListView` — `.navigationDestination
/// (for: String.self) { sessionId in SessionReviewView(sessionId:) }`),
/// поэтому роутер выставляет колбэк `onOpenSessionReview`, который
/// инициирует переход во view-слое (push в NavigationPath).
@MainActor
final class SpecialistRouter: SpecialistRoutingLogic {

    weak var coordinator: AppCoordinator?

    /// View подписывается, чтобы выполнить push при routeToSessionReview.
    var onOpenSessionReview: ((String) -> Void)?

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
        if let onOpenSessionReview {
            onOpenSessionReview(sessionId)
        } else {
            logger.warning("routeToSessionReview: callback is not wired (sessionId=\(sessionId, privacy: .public))")
        }
    }
}
