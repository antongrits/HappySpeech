import Foundation
import SwiftUI

// MARK: - ChildHomeViewModel

/// Observable holder that receives `ViewModel` from Presenter and exposes display state to View.
/// Conforms to `ChildHomeDisplayLogic` — the View never touches the Interactor.
@MainActor
@Observable
final class ChildHomeViewModel: ChildHomeDisplayLogic {
    var childName: String = ""
    var currentStreak: Int = 0
    var mascotMood: MascotMood = .idle
    var mascotPhrase: String?
    var isLoading: Bool = true
    var dailyMission: ChildHomeModels.DailyMission = .placeholder
    var soundProgress: [ChildHomeModels.SoundProgressItem] = []

    func displayFetch(_ viewModel: ChildHomeModels.Fetch.ViewModel) {
        self.childName = viewModel.childName
        self.currentStreak = viewModel.currentStreak
        self.mascotMood = viewModel.mascotMood
        self.mascotPhrase = viewModel.mascotPhrase
        self.dailyMission = viewModel.dailyMission
        self.soundProgress = viewModel.soundProgress
        self.isLoading = false
    }
}
