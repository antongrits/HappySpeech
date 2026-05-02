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
        case .openLesson(let soundId, let difficulty):
            handleOpenLesson(soundId: soundId, difficulty: difficulty)
        case .showProgress(let childName):
            handleShowProgress(childName: childName)
        case .startBreathing(let duration):
            handleStartBreathing(duration: duration)
        case .playWithLyalya:
            handlePlayWithLyalya()
        case .showTodaysMission:
            handleShowTodaysMission()
        case .startSession(let gameTemplate):
            handleStartSession(gameTemplate: gameTemplate)
        case .listAchievements:
            handleListAchievements()
        case .getWeeklySummary:
            handleGetWeeklySummary()
        case .setReminder(let hour, let minute):
            handleSetReminder(hour: hour, minute: minute)
        case .openRewardAlbum:
            handleOpenRewardAlbum()
        case .startCustomSession(let soundId, let rounds, let difficulty):
            handleStartCustomSession(soundId: soundId, rounds: rounds, difficulty: difficulty)
        }
    }

    // MARK: - Private route handlers

    private func handleOpenLesson(soundId: String, difficulty: String) {
        let childId = currentChildIdForSiri ?? ""
        push(.worldMap(childId: childId, targetSound: soundId))
    }

    private func handleShowProgress(childName: String?) {
        let childId = currentChildIdForSiri ?? ""
        navigate(to: .progressDashboard(childId: childId))
    }

    private func handleStartBreathing(duration: TimeInterval) {
        let childId = currentChildIdForSiri ?? ""
        push(.lessonPlayer(templateType: "breathing", childId: childId))
    }

    private func handlePlayWithLyalya() {
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

    private func handleStartSession(gameTemplate: String?) {
        let childId = currentChildIdForSiri ?? ""
        let template = gameTemplate ?? "adaptive"
        push(.lessonPlayer(templateType: template, childId: childId))
    }

    private func handleListAchievements() {
        let childId = currentChildIdForSiri ?? ""
        navigate(to: .achievements(childId: childId))
    }

    private func handleGetWeeklySummary() {
        let childId = currentChildIdForSiri ?? ""
        navigate(to: .progressDashboard(childId: childId))
    }

    private func handleSetReminder(hour: Int, minute: Int) {
        Self.siriLogger.info("Siri: установить напоминание в \(hour):\(String(format: "%02d", minute))")
    }

    private func handleOpenRewardAlbum() {
        let childId = currentChildIdForSiri ?? ""
        navigate(to: .rewards(childId: childId))
    }

    private func handleStartCustomSession(soundId: String, rounds: Int, difficulty: String) {
        let childId = currentChildIdForSiri ?? ""
        push(.lessonPlayer(templateType: "custom", childId: childId))
        Self.siriLogger.info("Siri custom session: sound=\(soundId) rounds=\(rounds) diff=\(difficulty)")
    }

    // MARK: - Helper

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
