import Foundation

// MARK: - ARZoneDisplayLogic

@MainActor
protocol ARZoneDisplayLogic: AnyObject {
    func displayLoadGames(_ viewModel: ARZoneModels.LoadGames.ViewModel)
    func displaySelectGame(_ viewModel: ARZoneModels.SelectGame.ViewModel)
    func displaySelectFallback(_ viewModel: ARZoneModels.SelectFallback.ViewModel)
    /// Показать tutorial sheet перед запуском игры.
    func displayShowTutorial(_ viewModel: ARZoneModels.SelectGame.ViewModel)
    /// Закрыть tutorial sheet и перейти к игре.
    func displayDismissTutorial(_ viewModel: ARZoneModels.DismissTutorial.ViewModel)
    /// Обновить баннер рекомендации планировщика.
    func displayRefreshPlannerAdvice(_ viewModel: ARZoneModels.RefreshPlannerAdvice.ViewModel)
}
