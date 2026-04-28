import Foundation

// MARK: - FamilyCalendarDisplayLogic
//
// Протокол отображения. Interactor → Presenter → View (Display).
// Все методы вызываются на @MainActor.

@MainActor
protocol FamilyCalendarDisplayLogic {
    func displayFamilyData(viewModel: FamilyCalendarViewModel)
    func displayError(message: String)
    func displayInsights(insights: [InsightItemViewModel])
    func displayDayDetail(viewModel: DayDetailViewModel)
    func displayLoadingState(isLoading: Bool)
    func displayInsightsLoading(isLoading: Bool)
    func displayClearToast()
}
