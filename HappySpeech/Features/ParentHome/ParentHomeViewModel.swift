import Foundation
import SwiftUI

// MARK: - ParentHomeViewModel

/// Observable holder that receives ViewModels from the Presenter
/// and exposes display state to the View. Conforms to `ParentHomeDisplayLogic`
/// — the View never talks to the Interactor directly.
@MainActor
@Observable
final class ParentHomeViewModel: ParentHomeDisplayLogic {

    // MARK: - Base state

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
    /// M6.16: Карточка скрининга. nil — скрининг не пройден.
    var screeningCard: ParentHomeModels.ScreeningCardViewModel?
    var isLoading: Bool = true
    var isEmpty: Bool = false

    // A.6: Multi-child
    var allChildren: [ParentHomeModels.ChildSummary] = []

    // A.6: Weekly stats + insights
    var weekStats: [ParentHomeModels.DayStat] = []
    var weeklyInsight: ParentHomeModels.WeeklyInsight?

    // A.6: Achievements
    var achievements: [ParentHomeModels.AchievementItem] = []

    // A.6: Notifications hub
    var notifications: [ParentHomeModels.NotificationItem] = []
    var unreadNotificationsCount: Int { notifications.filter { !$0.isRead }.count }

    // A.6: Quick actions
    var quickActions: [ParentHomeModels.QuickAction] = []

    // A.6: Flags
    var needsSpecialistReview: Bool = false
    var todaySessionsCount: Int = 0
    var todayMinutes: Int = 0

    // A.6: Navigation signals (cleared after consumption)
    var navigateToAddChild: Bool = false
    var navigateToSpecialistExport: String? = nil    // childId
    var navigateToStartLesson: String? = nil          // childId

    // A.6: Error toast
    var errorMessage: String? = nil

    // MARK: - DisplayLogic

    func displayFetch(_ viewModel: ParentHomeModels.Fetch.ViewModel) {
        childId = viewModel.childId
        childName = viewModel.childName
        childAge = viewModel.childAge
        targetSoundsText = viewModel.targetSoundsText
        greeting = viewModel.greeting
        currentStreak = viewModel.currentStreak
        totalSessionMinutes = viewModel.totalSessionMinutes
        overallRate = viewModel.overallRate
        lastSession = viewModel.lastSession
        recentSessions = viewModel.recentSessions
        soundProgress = viewModel.soundProgress
        homeTask = viewModel.homeTask
        recommendations = viewModel.recommendations
        screeningCard = viewModel.screeningCard
        allChildren = viewModel.allChildren
        achievements = viewModel.achievements
        notifications = viewModel.notifications
        quickActions = viewModel.quickActions
        needsSpecialistReview = viewModel.needsSpecialistReview
        todaySessionsCount = viewModel.todaySessionsCount
        todayMinutes = viewModel.todayMinutes
        isLoading = false
        isEmpty = viewModel.lastSession == nil && viewModel.recentSessions.isEmpty
    }

    func displayLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
    }

    func displayEmptyState() {
        isLoading = false
        isEmpty = true
    }

    func displayWeeklyInsight(_ response: ParentHomeModels.WeeklyInsightResponse) {
        weekStats = response.dayStat
        weeklyInsight = response.insight
    }

    func displayError(_ message: String) {
        errorMessage = message
    }

    func displayNavigateToAddChild() {
        navigateToAddChild = true
    }

    func displayNavigateToSpecialistExport(childId: String) {
        navigateToSpecialistExport = childId
    }

    func displayNavigateToStartLesson(childId: String) {
        navigateToStartLesson = childId
    }
}
