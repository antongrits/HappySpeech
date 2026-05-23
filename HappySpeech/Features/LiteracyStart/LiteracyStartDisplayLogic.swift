import Foundation

// MARK: - LiteracyStartDisplayLogic

/// Контракт Presenter → View (Holder).
@MainActor
protocol LiteracyStartDisplayLogic: AnyObject {
    func displayLoadLetter(viewModel: LiteracyStartModels.LoadLetter.ViewModel) async
    func displayUnsupportedSound(targetSound: String) async
}
