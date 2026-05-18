import Foundation

// MARK: - PhonemicListeningDisplayLogic
//
// v29 Фаза 8, Функция 12 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol PhonemicListeningDisplayLogic: AnyObject {
    func displayStart(viewModel: PhonemicListeningModels.Start.ViewModel) async
    func displayAnswer(viewModel: PhonemicListeningModels.Answer.ViewModel) async
}
