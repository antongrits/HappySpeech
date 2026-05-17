import SwiftUI

// MARK: - GuidedTourLaunchView

/// Достижимый экран обзорного тура.
///
/// Сам гайд-тур (`GuidedTourTipView` + `SpotlightOverlay`) рендерится как overlay
/// поверх всего навигационного стека через `GuidedTourContainer` в `AppCoordinatorView`.
/// Этот экран служит точкой входа: показывает `ChildHomeView` (на котором
/// зарегистрированы spotlight-якоря) и при появлении принудительно запускает тур.
///
/// Используется маршрутом `AppRoute.guidedTour` и debug-аргументом `-HSStartRoute guidedTour`.
struct GuidedTourLaunchView: View {

    @Environment(AppContainer.self) private var container

    var body: some View {
        ChildHomeView(childId: container.currentChildId)
            .onAppear {
                // force: true — перезапускаем тур даже если он был пройден ранее.
                container.guidedTourCoordinator.start(force: true)
            }
    }
}

#Preview {
    GuidedTourLaunchView()
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
}
