import Foundation
import OSLog

// MARK: - SpotlightDeepLinkHandler

/// Расширение AppCoordinator для обработки Spotlight deep links.
/// K.5 — Deep link routing: lesson / achievement / session.
extension AppCoordinator {

    private static let logger = Logger(
        subsystem: "ru.happyspeech.app",
        category: "SpotlightDeepLink"
    )

    /// Открывает экран урока по Spotlight-идентификатору.
    func navigateToLesson(id lessonId: String) {
        Self.logger.info("Spotlight deep link → урок: \(lessonId, privacy: .public)")
        // Открываем WorldMap с фокусом на звуке из lessonId.
        // lessonId формат: soundId (например "sound_sh_001" → soundTarget "Ш").
        // Используем lessonPlayer без конкретного childId — coordinator выберет активного ребёнка.
        push(.lessonPlayer(templateType: "listen-and-choose", childId: currentChildId ?? ""))
    }

    /// Открывает раздел достижений по Spotlight-идентификатору.
    func navigateToAchievement(id achId: String) {
        Self.logger.info("Spotlight deep link → достижение: \(achId, privacy: .public)")
        let childId = currentChildId ?? ""
        push(.achievements(childId: childId))
    }

    /// Открывает историю сессий, отфильтрованную по sessionId.
    func navigateToSession(id sessionId: String) {
        Self.logger.info("Spotlight deep link → сессия: \(sessionId, privacy: .public)")
        let childId = currentChildId ?? ""
        push(.sessionHistory(childId: childId))
    }

    /// Идентификатор активного ребёнка из состояния координатора.
    private var currentChildId: String? {
        switch currentRoute {
        case .childHome(let childId):
            return childId
        case .rewards(let childId), .progressDashboard(let childId),
             .sessionHistory(let childId), .worldMap(let childId, _),
             .achievements(let childId), .screening(let childId),
             .siblingMultiplayer(let childId):
            return childId
        default:
            return nil
        }
    }
}
