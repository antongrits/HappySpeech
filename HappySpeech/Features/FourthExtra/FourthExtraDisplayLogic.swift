import Foundation

// MARK: - FourthExtraDisplayLogic
//
// F2-005 «Четвёртый лишний» — Clean Swift: контракт View ← Presenter.

@MainActor
protocol FourthExtraDisplayLogic: AnyObject {
    func displayStart(viewModel: FourthExtraModels.Start.ViewModel) async
    func displayAnswer(viewModel: FourthExtraModels.Answer.ViewModel) async
}
