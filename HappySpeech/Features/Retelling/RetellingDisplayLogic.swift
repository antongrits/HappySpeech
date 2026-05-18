import Foundation

// MARK: - RetellingDisplayLogic
//
// v29 Фаза 8, Функция 2 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol RetellingDisplayLogic: AnyObject {
    func displayStart(viewModel: RetellingModels.Start.ViewModel) async
    func displayToggle(viewModel: RetellingModels.ToggleLink.ViewModel) async
    func displayFinish(viewModel: RetellingModels.Finish.ViewModel) async
}
