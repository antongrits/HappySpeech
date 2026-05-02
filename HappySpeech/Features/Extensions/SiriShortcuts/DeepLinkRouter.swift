import Foundation
import OSLog

// MARK: - DeepLinkAction

/// Действия навигации, инициированные App Intents (Siri Shortcuts).
public enum DeepLinkAction: Sendable {
    case openLesson(soundId: String, difficulty: String)
    case showProgress(childName: String?)
    case startBreathing(duration: TimeInterval)
    case playWithLyalya
    case showTodaysMission
    case startSession(gameTemplate: String?)
    case listAchievements
    case getWeeklySummary
    case setReminder(hour: Int, minute: Int)
    case openRewardAlbum
    case startCustomSession(soundId: String, rounds: Int, difficulty: String)
}

// MARK: - AppCoordinatorBridge

/// Протокол-мост между DeepLinkRouter и AppCoordinator.
/// Позволяет DeepLinkRouter не знать о конкретном классе AppCoordinator.
@MainActor
public protocol AppCoordinatorBridge: AnyObject {
    func handle(_ action: DeepLinkAction)
}

// MARK: - DeepLinkRouter

/// Singleton-маршрутизатор App Intents → AppCoordinator.
/// Хранит pending actions до регистрации coordinator,
/// затем воспроизводит их по порядку.
/// Используется только из @MainActor контекста.
@MainActor
public final class DeepLinkRouter {

    // MARK: - Shared

    public static let shared = DeepLinkRouter()

    // MARK: - Private

    private let logger = Logger(subsystem: "ru.happyspeech.app", category: "DeepLinkRouter")
    private weak var coordinator: (any AppCoordinatorBridge)?
    private var pendingActions: [DeepLinkAction] = []

    private init() {}

    // MARK: - Registration

    /// Регистрирует AppCoordinator после его инициализации.
    /// Воспроизводит все накопленные pending actions.
    public func register(coordinator: any AppCoordinatorBridge) {
        self.coordinator = coordinator
        logger.info("DeepLinkRouter: coordinator зарегистрирован, воспроизводим \(self.pendingActions.count) отложенных действий")
        for action in pendingActions {
            coordinator.handle(action)
        }
        pendingActions.removeAll()
    }

    // MARK: - Intent handlers

    public func handleOpenLesson(soundId: String, difficulty: String = "medium") {
        dispatch(.openLesson(soundId: soundId, difficulty: difficulty))
    }

    public func handleShowProgress(childName: String? = nil) {
        dispatch(.showProgress(childName: childName))
    }

    public func handleStartBreathing(duration: TimeInterval = 60) {
        dispatch(.startBreathing(duration: duration))
    }

    public func handlePlayWithLyalya() {
        dispatch(.playWithLyalya)
    }

    public func handleShowTodaysMission() {
        dispatch(.showTodaysMission)
    }

    public func handleStartSession(gameTemplate: String? = nil) {
        dispatch(.startSession(gameTemplate: gameTemplate))
    }

    public func handleListAchievements() {
        dispatch(.listAchievements)
    }

    public func handleGetWeeklySummary() {
        dispatch(.getWeeklySummary)
    }

    public func handleSetReminder(hour: Int, minute: Int) {
        dispatch(.setReminder(hour: hour, minute: minute))
    }

    public func handleOpenRewardAlbum() {
        dispatch(.openRewardAlbum)
    }

    public func handleStartCustomSession(soundId: String, rounds: Int, difficulty: String) {
        dispatch(.startCustomSession(soundId: soundId, rounds: rounds, difficulty: difficulty))
    }

    // MARK: - Dispatch

    private func dispatch(_ action: DeepLinkAction) {
        if let coordinator = coordinator {
            logger.info("DeepLinkRouter: dispatch \(String(describing: action), privacy: .public)")
            coordinator.handle(action)
        } else {
            logger.info("DeepLinkRouter: coordinator не готов — откладываем \(String(describing: action), privacy: .public)")
            pendingActions.append(action)
        }
    }
}
