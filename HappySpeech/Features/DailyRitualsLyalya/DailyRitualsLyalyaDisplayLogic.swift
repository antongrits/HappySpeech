import Foundation

// MARK: - DailyRitualsLyalyaDisplayLogic
//
// v31 Волна A, Функция Ф8 — Clean Swift: View ← Presenter.

@MainActor
protocol DailyRitualsLyalyaDisplayLogic: AnyObject {
    func displayLoad(viewModel: DailyRitualsLyalyaModels.Load.ViewModel) async
    func displayToggleReminder(response: DailyRitualsLyalyaModels.ToggleReminder.Response) async
    func displayUpdateTime(response: DailyRitualsLyalyaModels.UpdateTime.Response) async
    func displayPermissionResult(response: DailyRitualsLyalyaModels.RequestPermission.Response) async
}
