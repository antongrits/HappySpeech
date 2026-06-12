import SwiftUI

// MARK: - SoundOfTheDayRouter

/// VIP-Router. Передаёт навигационные намерения наружу — в AppCoordinator.
@MainActor
final class SoundOfTheDayRouter {

    weak var coordinator: AppCoordinator?

    func dismiss() {
        coordinator?.pop()
    }

    /// Открыть LessonPlayer с указанным шаблоном для активности.
    /// templateRoute совпадает с ключом из `GameType.fromTemplateRoute`
    /// (см. AppCoordinator + LessonPlayer). P0-2: `targetSound` — реальный звук
    /// дня, чтобы активность тренировала его, а не хардкод «Р».
    func routeToActivity(_ activity: ActivityCard, childId: String, targetSound: String = "") {
        coordinator?.navigate(to: .lessonPlayer(
            templateType: activity.templateRoute,
            childId: childId,
            targetSound: targetSound
        ))
    }
}
