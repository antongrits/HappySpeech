import Foundation

// MARK: - SpeechNormsEncyclopediaDisplayLogic
//
// v31 Волна A, Функция Ф10 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol SpeechNormsEncyclopediaDisplayLogic: AnyObject {
    func displayLoad(viewModel: SpeechNormsEncyclopediaModels.Load.ViewModel) async
}
