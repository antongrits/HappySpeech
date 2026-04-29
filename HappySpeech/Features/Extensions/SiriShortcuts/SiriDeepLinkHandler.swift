import Foundation
import OSLog

// MARK: - AppCoordinator + AppCoordinatorBridge

/// Conform AppCoordinator к AppCoordinatorBridge для обработки Siri App Intents.
/// Аналогично SpotlightDeepLinkHandler — изолированное расширение без изменения
/// основного файла AppCoordinator.
extension AppCoordinator: AppCoordinatorBridge {

    private static let siriLogger = Logger(
        subsystem: "ru.happyspeech.app",
        category: "SiriDeepLink"
    )

    /// Обрабатывает действие от DeepLinkRouter.
    /// Вызывается всегда на @MainActor (гарантируется AppCoordinatorBridge + DeepLinkRouter).
    public func handle(_ action: DeepLinkAction) {
        Self.siriLogger.info("Siri deep link → \(String(describing: action), privacy: .public)")
        switch action {
        case .openLesson(let soundId):
            handleOpenLesson(soundId: soundId)
        case .showProgress:
            handleShowProgress()
        case .startBreathing:
            handleStartBreathing()
        case .playWithLyalya:
            handlePlayWithLyalya()
        case .showTodaysMission:
            handleShowTodaysMission()
        }
    }

    // MARK: - Private route handlers

    private func handleOpenLesson(soundId: String) {
        let childId = currentChildIdForSiri ?? ""
        push(.worldMap(childId: childId, targetSound: soundId))
    }

    private func handleShowProgress() {
        let childId = currentChildIdForSiri ?? ""
        navigate(to: .progressDashboard(childId: childId))
    }

    private func handleStartBreathing() {
        let childId = currentChildIdForSiri ?? ""
        push(.lessonPlayer(templateType: "breathing", childId: childId))
    }

    private func handlePlayWithLyalya() {
        // Если уже на childHome — ничего не делаем, иначе навигируем
        switch currentRoute {
        case .childHome:
            return
        default:
            navigate(to: .childHome(childId: currentChildIdForSiri ?? ""))
        }
    }

    private func handleShowTodaysMission() {
        let childId = currentChildIdForSiri ?? ""
        navigate(to: .childHome(childId: childId))
    }

    /// Идентификатор активного ребёнка — реиспользуем паттерн из SpotlightDeepLinkHandler.
    private var currentChildIdForSiri: String? {
        switch currentRoute {
        case .childHome(let childId):
            return childId
        case .rewards(let childId),
             .progressDashboard(let childId),
             .sessionHistory(let childId),
             .worldMap(let childId, _),
             .achievements(let childId),
             .screening(let childId),
             .siblingMultiplayer(let childId):
            return childId
        default:
            return nil
        }
    }
}
