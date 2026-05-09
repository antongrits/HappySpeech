import Foundation

// MARK: - DialectAdaptationDisplayLogic
//
// Block R.1 v18 — Clean Swift: контракт View ← Presenter.
//
// Все методы вызываются Presenter-ом на @MainActor. ViewModel-ы Sendable —
// безопасны для async-передачи.

@MainActor
protocol DialectAdaptationDisplayLogic: AnyObject {
    func displayLoad(viewModel: DialectAdaptationModels.Load.ViewModel) async
    func displaySelect(viewModel: DialectAdaptationModels.Select.ViewModel) async
    func displayReset(viewModel: DialectAdaptationModels.Reset.ViewModel) async
}
