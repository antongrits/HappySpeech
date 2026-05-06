import Foundation

// MARK: - AchievementsDisplayLogic

@MainActor
protocol AchievementsDisplayLogic: AnyObject {
    func displayAchievements(_ viewModel: AchievementsModels.Load.ViewModel)
    func displayUnlockedToast(_ viewModel: AchievementsModels.ToastUnlocked.ViewModel)
    func displayNextAchievementProgress(_ viewModel: AchievementsModels.NextAchievementProgress.ViewModel)
    func displayMotivationalMessage(_ message: String)
    func displayShareSheet(shareText: String, achievement: Achievement)
}
