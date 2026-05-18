import Foundation

// MARK: - SpeechTempoDisplayLogic
//
// v29 Фаза 8, Функция 6 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol SpeechTempoDisplayLogic: AnyObject {
    func displayStart(viewModel: SpeechTempoModels.Start.ViewModel) async
    func displayFinish(viewModel: SpeechTempoModels.Finish.ViewModel) async
}
