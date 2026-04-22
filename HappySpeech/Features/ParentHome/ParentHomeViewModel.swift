import Foundation
import SwiftUI

// MARK: - ParentHomeViewModel

/// Observable holder that receives ViewModels from the Presenter
/// and exposes display state to the View. Conforms to `ParentHomeDisplayLogic`
/// — the View never talks to the Interactor directly.
@MainActor
@Observable
final class ParentHomeViewModel: ParentHomeDisplayLogic {

    var childId: String = ""
    var childName: String = ""
    var childAge: Int = 0
    var targetSoundsText: String = ""
    var greeting: String = ""
    var currentStreak: Int = 0
    var totalSessionMinutes: Int = 0
    var overallRate: Double = 0.0
    var lastSession: ParentHomeModels.SessionSummary?
    var recentSessions: [ParentHomeModels.SessionSummary] = []
    var soundProgress: [ParentHomeModels.SoundProgress] = []
    var homeTask: String?
    var recommendations: [String] = []
    var isLoading: Bool = true
    var isEmpty: Bool = false

    func displayFetch(_ viewModel: ParentHomeModels.Fetch.ViewModel) {
        self.childId = viewModel.childId
        self.childName = viewModel.childName
        self.childAge = viewModel.childAge
        self.targetSoundsText = viewModel.targetSoundsText
        self.greeting = viewModel.greeting
        self.currentStreak = viewModel.currentStreak
        self.totalSessionMinutes = viewModel.totalSessionMinutes
        self.overallRate = viewModel.overallRate
        self.lastSession = viewModel.lastSession
        self.recentSessions = viewModel.recentSessions
        self.soundProgress = viewModel.soundProgress
        self.homeTask = viewModel.homeTask
        self.recommendations = viewModel.recommendations
        self.isLoading = false
        self.isEmpty = viewModel.lastSession == nil && viewModel.recentSessions.isEmpty
    }

    func displayLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
    }

    func displayEmptyState() {
        self.isLoading = false
        self.isEmpty = true
    }
}
