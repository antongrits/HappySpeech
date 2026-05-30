import Foundation

// MARK: - SoundDetectiveDisplayLogic
//
// F2-009 «Звуковой детектив» — Clean Swift: контракт View ← Presenter.

@MainActor
protocol SoundDetectiveDisplayLogic: AnyObject {
    func displayStart(viewModel: SoundDetectiveModels.Start.ViewModel) async
    func displayAnswer(viewModel: SoundDetectiveModels.Answer.ViewModel) async
}
