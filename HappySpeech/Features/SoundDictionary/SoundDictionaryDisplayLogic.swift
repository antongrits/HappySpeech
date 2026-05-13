import Foundation

// MARK: - SoundDictionaryDisplayLogic
//
// Block AE v21 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol SoundDictionaryDisplayLogic: AnyObject {
    func displayLoad(viewModel: SoundDictionaryModels.Load.ViewModel) async
    func displaySelectPhoneme(viewModel: SoundDictionaryModels.SelectPhoneme.ViewModel) async
    func displayPlayAudio(viewModel: SoundDictionaryModels.PlayAudio.ViewModel) async
    func displayPracticePhoneme(viewModel: SoundDictionaryModels.PracticePhoneme.ViewModel) async
}
