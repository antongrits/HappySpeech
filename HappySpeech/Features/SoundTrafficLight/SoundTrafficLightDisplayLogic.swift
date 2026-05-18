import Foundation

// MARK: - SoundTrafficLightDisplayLogic
//
// v29 Фаза 8, Функция 5 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol SoundTrafficLightDisplayLogic: AnyObject {
    func displayStart(viewModel: SoundTrafficLightModels.Start.ViewModel) async
    func displaySort(viewModel: SoundTrafficLightModels.Sort.ViewModel) async
}
