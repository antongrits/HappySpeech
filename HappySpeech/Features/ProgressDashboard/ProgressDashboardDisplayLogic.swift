import Foundation
import Observation

// MARK: - ProgressDashboardDisplayLogic

@MainActor
protocol ProgressDashboardDisplayLogic: AnyObject {
    func displayLoadDashboard(_ viewModel: ProgressDashboardModels.LoadDashboard.ViewModel)
    func displayLoadSoundDetail(_ viewModel: ProgressDashboardModels.LoadSoundDetail.ViewModel)
    func displayRequestLLMSummary(_ viewModel: ProgressDashboardModels.RequestLLMSummary.ViewModel)
    func displayFailure(_ viewModel: ProgressDashboardModels.Failure.ViewModel)
    func displayLoading(_ isLoading: Bool)
    func displayLLMLoading(_ isLoading: Bool)
}

// MARK: - ProgressDashboardDisplay (Observable Store)

@Observable
@MainActor
final class ProgressDashboardDisplay: ProgressDashboardDisplayLogic {

    var summaryCards: [SummaryCardViewModel] = []
    var dailyChart: [DailyChartPoint] = []
    var weeklyChart: [WeeklyChartPoint] = []
    var dailyAxisLabels: [String] = []
    var soundCells: [SoundProgressCellViewModel] = []

    var llmSummary: LLMSummaryViewModel?
    var isLLMLoading: Bool = false

    var pendingSoundDetail: SoundDetailViewModel?

    var isLoading: Bool = false
    var isEmpty: Bool = false
    var emptyTitle: String = ""
    var emptyMessage: String = ""

    var toastMessage: String?

    // MARK: - DisplayLogic

    func displayLoadDashboard(_ viewModel: ProgressDashboardModels.LoadDashboard.ViewModel) {
        summaryCards = viewModel.summaryCards
        dailyChart = viewModel.dailyChart
        weeklyChart = viewModel.weeklyChart
        dailyAxisLabels = viewModel.dailyAxisLabels
        soundCells = viewModel.soundCells
        isEmpty = viewModel.isEmpty
        emptyTitle = viewModel.emptyTitle
        emptyMessage = viewModel.emptyMessage
        isLoading = false
    }

    func displayLoadSoundDetail(_ viewModel: ProgressDashboardModels.LoadSoundDetail.ViewModel) {
        pendingSoundDetail = viewModel.detail
    }

    func displayRequestLLMSummary(_ viewModel: ProgressDashboardModels.RequestLLMSummary.ViewModel) {
        llmSummary = viewModel.summary
        isLLMLoading = false
    }

    func displayFailure(_ viewModel: ProgressDashboardModels.Failure.ViewModel) {
        toastMessage = viewModel.toastMessage
        isLoading = false
        isLLMLoading = false
    }

    func displayLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
    }

    func displayLLMLoading(_ isLoading: Bool) {
        self.isLLMLoading = isLoading
    }

    func clearToast() { toastMessage = nil }

    func consumePendingDetail() { pendingSoundDetail = nil }
}
