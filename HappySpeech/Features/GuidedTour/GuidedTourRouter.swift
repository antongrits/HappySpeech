import Foundation
import OSLog

// MARK: - GuidedTourRouter
//
// Block I v16 — VIP Router.
//
// GuidedTour — это overlay поверх любого экрана; основная навигация после
// завершения тура чаще всего НЕ требуется (тур исчезает, пользователь видит
// тот же экран). Однако для полноты VIP контракта Router выставляет
// два slot'а:
//   1. routeAfterTourCompletion() — вызывается после `complete()` /  `skip()`.
//      По умолчанию no-op, но Settings-сценарий может подменить closure.
//   2. routeToHome() — переход в kid home (используется кнопкой
//      "Понятно!" на финальном шаге, если тур запущен из Splash/Onboarding).
//
// AppCoordinator передаётся weak. Если он `nil` — Router логирует и тихо
// игнорирует (overlay просто закрывается).

@MainActor
final class GuidedTourRouter: GuidedTourRoutingLogic {

    // MARK: - Inputs

    weak var coordinator: AppCoordinator?

    /// Пользовательский callback (например, "после финального шага открыть
    /// Settings → Reminder"). Имеет приоритет над coordinator.
    var onTourCompleted: (() -> Void)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "GuidedTourRouter")

    // MARK: - Init

    init(coordinator: AppCoordinator? = nil) {
        self.coordinator = coordinator
    }

    // MARK: - Routing

    func routeAfterTourCompletion() {
        if let onTourCompleted {
            onTourCompleted()
            return
        }
        // Базовый сценарий — overlay просто закрывается, навигация не нужна.
        logger.debug("routeAfterTourCompletion: noop (overlay closed)")
    }

    func routeToHome() {
        guard let coordinator else {
            logger.debug("routeToHome: coordinator nil — noop")
            return
        }
        coordinator.navigate(to: .childHome(childId: "primary-child"))
    }
}
