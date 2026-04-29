import Foundation

// MARK: - SeasonalEventsRouter
//
// Навигация из SeasonalBannerView. Маршрутизирует к сезонному уроку через AppCoordinator.

@MainActor
final class SeasonalEventsRouter {

    weak var coordinator: AppCoordinator?

    func routeToSeasonalLesson(event: SeasonalEvent, childId: String) {
        coordinator?.push(.lessonPlayer(templateType: "repeat-after-model", childId: childId))
    }
}
