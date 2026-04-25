import Foundation
import SwiftUI

// MARK: - ChildHomeViewModel

/// Observable holder that receives `ViewModel` from Presenter and exposes display state to View.
/// Conforms to `ChildHomeDisplayLogic` — the View never touches the Interactor.
@MainActor
@Observable
final class ChildHomeViewModel: ChildHomeDisplayLogic {

    // MARK: - Legacy display state

    var childName: String = ""
    var currentStreak: Int = 0
    var mascotMood: MascotMood = .idle
    var mascotPhrase: String?
    var isLoading: Bool = true
    var dailyMission: ChildHomeModels.DailyMission = .placeholder
    var soundProgress: [ChildHomeModels.SoundProgressItem] = []

    // MARK: - Sprint 8.7 display state

    var quickPlayItems: [ChildHomeModels.QuickPlayItem] = []
    var worldZones: [ChildHomeModels.WorldZonePreview] = []
    var recentSessions: [ChildHomeModels.RecentSession] = []
    var achievement: ChildHomeModels.Achievement?
    var dailyMissionDetail: ChildHomeModels.DailyMissionDetail = .placeholder
    var formattedDate: String = ""
    var isStreakHot: Bool = false

    // MARK: - Computed helpers

    var displayedName: String {
        childName.isEmpty
            ? String(localized: "child.default.name")
            : childName
    }

    var hasAchievement: Bool {
        achievement?.isVisible == true
    }

    // MARK: - DisplayLogic

    func displayFetch(_ viewModel: ChildHomeModels.Fetch.ViewModel) {
        self.childName          = viewModel.childName
        self.currentStreak      = viewModel.currentStreak
        self.mascotMood         = viewModel.mascotMood
        self.mascotPhrase       = viewModel.mascotPhrase
        self.dailyMission       = viewModel.dailyMission
        self.soundProgress      = viewModel.soundProgress

        // Sprint 8.7
        self.quickPlayItems     = viewModel.quickPlayItems
        self.worldZones         = viewModel.worldZones
        self.recentSessions     = viewModel.recentSessions
        self.achievement        = viewModel.achievement
        self.dailyMissionDetail = viewModel.dailyMissionDetail
        self.formattedDate      = viewModel.formattedDate
        self.isStreakHot        = viewModel.isStreakHot

        self.isLoading          = false
    }
}
