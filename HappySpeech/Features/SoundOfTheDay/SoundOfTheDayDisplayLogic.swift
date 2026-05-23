import Foundation

// MARK: - SoundOfTheDayDisplayLogic

/// Контракт Presenter → View (Holder).
@MainActor
protocol SoundOfTheDayDisplayLogic: AnyObject {
    func displayLoadToday(viewModel: SoundOfTheDayModels.LoadToday.ViewModel) async
}
