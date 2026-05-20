import Foundation

// MARK: - ComprehensionDetectiveDisplayLogic

@MainActor
protocol ComprehensionDetectiveDisplayLogic: AnyObject {
    func displayStart(viewModel: ComprehensionDetectiveModels.Start.ViewModel) async
    func displayPick(viewModel: ComprehensionDetectiveModels.Pick.ViewModel) async
}
