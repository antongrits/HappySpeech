import Foundation

// MARK: - ParentInsightsTimelineDisplayLogic
//
// Block AE batch 2 v21 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol ParentInsightsTimelineDisplayLogic: AnyObject {
    func displayLoad(viewModel: ParentInsightsTimelineModels.Load.ViewModel) async
    func displaySelectDay(viewModel: ParentInsightsTimelineModels.SelectDay.ViewModel) async
    func displayRefresh(viewModel: ParentInsightsTimelineModels.Refresh.ViewModel) async
}
