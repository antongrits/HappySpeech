import Foundation

// MARK: - BreatheAndSpeakDisplayLogic
//
// v29 Фаза 8, Функция 10 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol BreatheAndSpeakDisplayLogic: AnyObject {
    func displayStart(viewModel: BreatheAndSpeakModels.Start.ViewModel) async
    func displayAdvance(viewModel: BreatheAndSpeakModels.Advance.ViewModel) async
}
