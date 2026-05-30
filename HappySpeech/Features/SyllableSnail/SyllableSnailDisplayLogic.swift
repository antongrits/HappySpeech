import Foundation

// MARK: - SyllableSnailDisplayLogic
//
// F2-003 «Слоговая улитка» — Clean Swift: контракт View ← Presenter.

@MainActor
protocol SyllableSnailDisplayLogic: AnyObject {
    func displayStart(viewModel: SyllableSnailModels.Start.ViewModel) async
    func displayTap(viewModel: SyllableSnailModels.Tap.ViewModel) async
    func displaySubmit(viewModel: SyllableSnailModels.Submit.ViewModel) async
    func displayFix(viewModel: SyllableSnailModels.Fix.ViewModel) async
}
