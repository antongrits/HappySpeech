import Foundation
import Observation

// MARK: - SessionHistoryChartPoint

struct SessionHistoryChartPoint: Sendable, Identifiable, Equatable, Hashable {
    let id: String
    let date: Date
    let accuracyPercent: Double
}

// MARK: - SessionHistoryDisplayLogic

@MainActor
protocol SessionHistoryDisplayLogic: AnyObject {
    func displayLoadHistory(_ viewModel: SessionHistoryModels.LoadHistory.ViewModel)
    func displayApplyFilter(_ viewModel: SessionHistoryModels.ApplyFilter.ViewModel)
    func displayClearFilter(_ viewModel: SessionHistoryModels.ClearFilter.ViewModel)
    func displayApplySort(_ viewModel: SessionHistoryModels.ApplySort.ViewModel)
    func displayLoadNextPage(_ viewModel: SessionHistoryModels.LoadNextPage.ViewModel)
    func displayOpenSession(_ viewModel: SessionHistoryModels.OpenSession.ViewModel)
    func displayAddNote(_ viewModel: SessionHistoryModels.AddNote.ViewModel)
    func displayDeleteNote(_ viewModel: SessionHistoryModels.DeleteNote.ViewModel)
    func displayExportPDF(_ viewModel: SessionHistoryModels.ExportPDF.ViewModel)
    func displayExportCSV(_ viewModel: SessionHistoryModels.ExportCSV.ViewModel)
    func displayExportJSON(_ viewModel: SessionHistoryModels.ExportJSON.ViewModel)
    func displayAudioState(_ viewModel: SessionHistoryModels.AudioState.ViewModel)
    func displayStatsSummary(_ viewModel: SessionHistoryModels.LoadStatsSummary.ViewModel)
    func displayLyalyaComment(_ viewModel: SessionHistoryModels.LoadLyalyaComment.ViewModel)
    func displaySearch(_ viewModel: SessionHistoryModels.Search.ViewModel)
    func displayFailure(_ viewModel: SessionHistoryModels.Failure.ViewModel)
    func displayLoading(_ isLoading: Bool)
}

// MARK: - SessionHistoryDisplay (Observable Store)

@Observable
@MainActor
final class SessionHistoryDisplay: SessionHistoryDisplayLogic {

    // MARK: - List state

    var groups: [SessionMonthGroup] = []
    var totalCount: Int = 0
    var filteredCount: Int = 0
    var activeFilter: SessionHistoryFilter = .empty
    var activeSort: SessionHistorySort = .byDate
    var activeSoundChips: [String] = []
    var currentPage: Int = 0
    var isLastPage: Bool = false

    // MARK: - Empty / loading / error

    var isEmpty: Bool = false
    var emptyKind: EmptyKind = .none
    var emptyTitle: String = ""
    var emptyMessage: String = ""
    var isLoading: Bool = false
    var toastMessage: String?

    // MARK: - Detail (push-destination)

    var pendingDetail: SessionDetailViewModel?

    // MARK: - Notes

    var notesBySession: [String: String] = [:]

    // MARK: - Export

    var pendingShareURL: URL?

    // MARK: - Audio

    var audioStateBySession: [String: SessionHistoryModels.AudioState.ViewModel] = [:]

    // MARK: - Stats summary

    var statsSummary: SessionHistoryModels.LoadStatsSummary.ViewModel?

    // MARK: - Lyalya

    var lyalyaComment: String = ""

    // MARK: - Search

    var searchQuery: String = ""

    // MARK: - DisplayLogic

    func displayLoadHistory(_ viewModel: SessionHistoryModels.LoadHistory.ViewModel) {
        groups = viewModel.groups
        totalCount = viewModel.totalCount
        filteredCount = viewModel.filteredCount
        activeFilter = viewModel.activeFilter
        activeSort = viewModel.activeSort
        activeSoundChips = viewModel.activeSoundChips
        isEmpty = viewModel.isEmpty
        emptyKind = viewModel.emptyKind
        emptyTitle = viewModel.emptyTitle
        emptyMessage = viewModel.emptyMessage
        currentPage = viewModel.currentPage
        isLastPage = viewModel.isLastPage
        isLoading = false
    }

    func displayApplyFilter(_ viewModel: SessionHistoryModels.ApplyFilter.ViewModel) {
        groups = viewModel.groups
        totalCount = viewModel.totalCount
        filteredCount = viewModel.filteredCount
        activeFilter = viewModel.activeFilter
        activeSort = viewModel.activeSort
        activeSoundChips = viewModel.activeSoundChips
        isEmpty = viewModel.isEmpty
        emptyKind = viewModel.emptyKind
        emptyTitle = viewModel.emptyTitle
        emptyMessage = viewModel.emptyMessage
        currentPage = viewModel.currentPage
        isLastPage = viewModel.isLastPage
    }

    func displayClearFilter(_ viewModel: SessionHistoryModels.ClearFilter.ViewModel) {
        groups = viewModel.groups
        totalCount = viewModel.totalCount
        filteredCount = viewModel.filteredCount
        activeFilter = viewModel.activeFilter
        activeSort = viewModel.activeSort
        activeSoundChips = viewModel.activeSoundChips
        isEmpty = viewModel.isEmpty
        emptyKind = viewModel.emptyKind
        emptyTitle = viewModel.emptyTitle
        emptyMessage = viewModel.emptyMessage
        currentPage = viewModel.currentPage
        isLastPage = viewModel.isLastPage
        searchQuery = ""
    }

    func displayApplySort(_ viewModel: SessionHistoryModels.ApplySort.ViewModel) {
        groups = viewModel.groups
        totalCount = viewModel.totalCount
        filteredCount = viewModel.filteredCount
        activeFilter = viewModel.activeFilter
        activeSort = viewModel.activeSort
        activeSoundChips = viewModel.activeSoundChips
        isEmpty = viewModel.isEmpty
        emptyKind = viewModel.emptyKind
        emptyTitle = viewModel.emptyTitle
        emptyMessage = viewModel.emptyMessage
        currentPage = viewModel.currentPage
        isLastPage = viewModel.isLastPage
    }

    func displayLoadNextPage(_ viewModel: SessionHistoryModels.LoadNextPage.ViewModel) {
        // Добавляем новые группы (merge по id, не дублируем)
        for newGroup in viewModel.newGroups {
            if let existingIndex = groups.firstIndex(where: { $0.id == newGroup.id }) {
                let existingRows = groups[existingIndex].rows
                let merged = existingRows + newGroup.rows.filter { newRow in
                    !existingRows.contains(where: { $0.id == newRow.id })
                }
                groups[existingIndex] = SessionMonthGroup(
                    id: newGroup.id,
                    monthTitle: newGroup.monthTitle,
                    rows: merged
                )
            } else {
                groups.append(newGroup)
            }
        }
        currentPage = viewModel.currentPage
        isLastPage = viewModel.isLastPage
    }

    func displayOpenSession(_ viewModel: SessionHistoryModels.OpenSession.ViewModel) {
        pendingDetail = viewModel.detail
    }

    func displayAddNote(_ viewModel: SessionHistoryModels.AddNote.ViewModel) {
        notesBySession[viewModel.sessionId] = viewModel.noteText
        toastMessage = viewModel.toastMessage
    }

    func displayDeleteNote(_ viewModel: SessionHistoryModels.DeleteNote.ViewModel) {
        notesBySession.removeValue(forKey: viewModel.sessionId)
    }

    func displayExportPDF(_ viewModel: SessionHistoryModels.ExportPDF.ViewModel) {
        pendingShareURL = viewModel.shareURL
        toastMessage = viewModel.toastMessage
    }

    func displayExportCSV(_ viewModel: SessionHistoryModels.ExportCSV.ViewModel) {
        pendingShareURL = viewModel.shareURL
        toastMessage = viewModel.toastMessage
    }

    func displayExportJSON(_ viewModel: SessionHistoryModels.ExportJSON.ViewModel) {
        pendingShareURL = viewModel.shareURL
        toastMessage = viewModel.toastMessage
    }

    func displayAudioState(_ viewModel: SessionHistoryModels.AudioState.ViewModel) {
        audioStateBySession[viewModel.sessionId] = viewModel
    }

    func displayStatsSummary(_ viewModel: SessionHistoryModels.LoadStatsSummary.ViewModel) {
        statsSummary = viewModel
    }

    func displayLyalyaComment(_ viewModel: SessionHistoryModels.LoadLyalyaComment.ViewModel) {
        lyalyaComment = viewModel.commentText
    }

    func displaySearch(_ viewModel: SessionHistoryModels.Search.ViewModel) {
        groups = viewModel.groups
        totalCount = viewModel.totalCount
        filteredCount = viewModel.filteredCount
        isEmpty = viewModel.isEmpty
        emptyKind = viewModel.emptyKind
        emptyTitle = viewModel.emptyTitle
        emptyMessage = viewModel.emptyMessage
        currentPage = viewModel.currentPage
        isLastPage = viewModel.isLastPage
        searchQuery = viewModel.query
    }

    func displayFailure(_ viewModel: SessionHistoryModels.Failure.ViewModel) {
        toastMessage = viewModel.toastMessage
        isLoading = false
    }

    func displayLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
    }

    // MARK: - Mutations

    func clearToast() {
        toastMessage = nil
    }

    func consumePendingDetail() {
        pendingDetail = nil
    }

    func consumePendingShareURL() {
        pendingShareURL = nil
    }

    // MARK: - Chart / Summary derivations

    func chartPoints(limit: Int = 14) -> [SessionHistoryChartPoint] {
        guard !groups.isEmpty else { return [] }

        struct ChartRow {
            let id: String
            let date: Date
            let percent: Double
        }
        var rows: [ChartRow] = []
        let calendar = Calendar.current

        for group in groups {
            for row in group.rows {
                guard let percent = parsePercent(row.scoreText) else { continue }
                guard let date = inferDate(
                    monthGroupId: group.id,
                    dayNumber: row.dayNumber,
                    calendar: calendar
                ) else { continue }
                rows.append(ChartRow(id: row.id, date: date, percent: percent))
            }
        }

        rows.sort { $0.date < $1.date }
        let trimmed = rows.suffix(limit)
        return trimmed.map { row in
            SessionHistoryChartPoint(
                id: row.id,
                date: row.date,
                accuracyPercent: row.percent
            )
        }
    }

    func averageAccuracyPercent() -> Int {
        var total: Double = 0
        var count: Int = 0
        for group in groups {
            for row in group.rows {
                if let percent = parsePercent(row.scoreText) {
                    total += percent
                    count += 1
                }
            }
        }
        guard count > 0 else { return 0 }
        return Int((total / Double(count)).rounded())
    }

    func totalDurationMinutes() -> Int {
        var sum = 0
        for group in groups {
            for row in group.rows {
                sum += parseMinutes(row.durationText)
            }
        }
        return sum
    }

    // MARK: - Helpers

    private func parsePercent(_ text: String) -> Double? {
        let trimmed = text.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
        return Double(trimmed)
    }

    private func parseMinutes(_ text: String) -> Int {
        let digits = text.compactMap { $0.isNumber ? $0 : nil }
        return Int(String(digits)) ?? 0
    }

    private func inferDate(
        monthGroupId: String,
        dayNumber: String,
        calendar: Calendar
    ) -> Date? {
        let parts = monthGroupId.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(dayNumber) else { return nil }
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 12
        return calendar.date(from: comps)
    }
}
