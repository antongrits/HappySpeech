import OSLog
import SwiftUI

// MARK: - MethodologyAssistantRoutingLogic

@MainActor
protocol MethodologyAssistantRoutingLogic: AnyObject {
    /// Закрыть экран (вернуться назад).
    func routeBack()
}

// MARK: - MethodologyAssistantRouter

/// Роутер помощника по методике. Экран — модальный/push внутри взрослого
/// контура, навигация наружу не требуется кроме закрытия.
@MainActor
final class MethodologyAssistantRouter: MethodologyAssistantRoutingLogic {

    weak var coordinator: AppCoordinator?

    private let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "MethodologyAssistant.Router"
    )

    func routeBack() {
        logger.info("methodologyAssistant: routeBack")
        coordinator?.pop()
    }
}
