import Foundation
import OSLog

// MARK: - DeepLinkAction

/// Действия навигации, инициированные App Intents (Siri Shortcuts).
public enum DeepLinkAction: Sendable {
    case openLesson(soundId: String)
    case showProgress
    case startBreathing
    case playWithLyalya
    case showTodaysMission
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

    public func handleOpenLesson(soundId: String) {
        dispatch(.openLesson(soundId: soundId))
    }

    public func handleShowProgress() {
        dispatch(.showProgress)
    }

    public func handleStartBreathing() {
        dispatch(.startBreathing)
    }

    public func handlePlayWithLyalya() {
        dispatch(.playWithLyalya)
    }

    public func handleShowTodaysMission() {
        dispatch(.showTodaysMission)
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
