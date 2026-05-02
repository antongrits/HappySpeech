import Foundation

// MARK: - ParentHomeDisplayLogic

@MainActor
protocol ParentHomeDisplayLogic: AnyObject {
    func displayFetch(_ viewModel: ParentHomeModels.Fetch.ViewModel)
    func displayLoading(_ isLoading: Bool)
    func displayEmptyState()
    // A.6
    func displayWeeklyInsight(_ response: ParentHomeModels.WeeklyInsightResponse)
    func displayError(_ message: String)
    func displayNavigateToAddChild()
    func displayNavigateToSpecialistExport(childId: String)
    func displayNavigateToStartLesson(childId: String)
}
