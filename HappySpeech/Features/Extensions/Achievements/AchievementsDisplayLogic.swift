import Foundation

// MARK: - AchievementsDisplayLogic

@MainActor
protocol AchievementsDisplayLogic: AnyObject {
    func displayAchievements(_ viewModel: AchievementsModels.Load.ViewModel)
    func displayUnlockedToast(_ viewModel: AchievementsModels.ToastUnlocked.ViewModel)
}
