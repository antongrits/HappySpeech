import Foundation

// MARK: - SoundTrafficLightDisplayLogic
//
// v29 Фаза 8, Функция 5 — Clean Swift: контракт View ← Presenter.
// Покрывает все уровни лестницы: слог/слово (sort), фраза, текст.

@MainActor
protocol SoundTrafficLightDisplayLogic: AnyObject {
    func displayStart(viewModel: SoundTrafficLightModels.Start.ViewModel) async
    func displaySort(viewModel: SoundTrafficLightModels.Sort.ViewModel) async
    func displayChoosePhrase(viewModel: SoundTrafficLightModels.ChoosePhrase.ViewModel) async
    func displayCountText(viewModel: SoundTrafficLightModels.CountText.ViewModel) async
}
