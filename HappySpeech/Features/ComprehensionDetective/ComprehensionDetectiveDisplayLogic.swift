import Foundation

// MARK: - ComprehensionDetectiveDisplayLogic
//
// v31 Волна B Ф.2 «Понимание-детектив» — Clean Swift: контракт View ← Presenter.

@MainActor
protocol ComprehensionDetectiveDisplayLogic: AnyObject {
    func displayStart(viewModel: ComprehensionDetectiveModels.Start.ViewModel) async
    func displayPick(viewModel: ComprehensionDetectiveModels.Pick.ViewModel) async
}
