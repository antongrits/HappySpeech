import Foundation
import Observation

// MARK: - SessionHistoryChartPoint

/// Точка для Swift Charts (лёгкий ViewModel-тип).
/// Готовится в Display из текущих `groups` — без обращения к Interactor.
struct SessionHistoryChartPoint: Sendable, Identifiable, Equatable, Hashable {
    let id: String
    let date: Date
    let accuracyPercent: Double
}

// MARK: - SessionHistoryDisplayLogic

/// Контракт между Presenter и SwiftUI-store: Presenter заполняет ViewModel,
/// `display(_:)`-методы пишут поля в `SessionHistoryDisplay`, и SwiftUI ре-рендерит UI.
@MainActor
protocol SessionHistoryDisplayLogic: AnyObject {
    func displayLoadHistory(_ viewModel: SessionHistoryModels.LoadHistory.ViewModel)
    func displayApplyFilter(_ viewModel: SessionHistoryModels.ApplyFilter.ViewModel)
    func displayClearFilter(_ viewModel: SessionHistoryModels.ClearFilter.ViewModel)
    func displayOpenSession(_ viewModel: SessionHistoryModels.OpenSession.ViewModel)
    func displayFailure(_ viewModel: SessionHistoryModels.Failure.ViewModel)
    func displayLoading(_ isLoading: Bool)
}

// MARK: - SessionHistoryDisplay (Observable Store)

/// Источник истины для SwiftUI-вью. Никакой бизнес-логики — только состояние.
@Observable
@MainActor
final class SessionHistoryDisplay: SessionHistoryDisplayLogic {

    // Список групп сессий по месяцам — готов к ForEach.
    var groups: [SessionMonthGroup] = []

    // Счётчики и фильтр.
    var totalCount: Int = 0
    var filteredCount: Int = 0
    var activeFilter: SessionFilter = .empty
    var activeSoundChips: [String] = []

    // Empty / loading / error.
    var isEmpty: Bool = false
    var emptyKind: EmptyKind = .none
    var emptyTitle: String = ""
    var emptyMessage: String = ""
    var isLoading: Bool = false
    var toastMessage: String?

    // Detail (push-цель).
    var pendingDetail: SessionDetailViewModel?

    // MARK: - SessionHistoryDisplayLogic

    func displayLoadHistory(_ viewModel: SessionHistoryModels.LoadHistory.ViewModel) {
        groups = viewModel.groups
        totalCount = viewModel.totalCount
        filteredCount = viewModel.filteredCount
        activeFilter = viewModel.activeFilter
        activeSoundChips = viewModel.activeSoundChips
        isEmpty = viewModel.isEmpty
        emptyKind = viewModel.emptyKind
        emptyTitle = viewModel.emptyTitle
        emptyMessage = viewModel.emptyMessage
        isLoading = false
    }

    func displayApplyFilter(_ viewModel: SessionHistoryModels.ApplyFilter.ViewModel) {
        groups = viewModel.groups
        totalCount = viewModel.totalCount
        filteredCount = viewModel.filteredCount
        activeFilter = viewModel.activeFilter
        activeSoundChips = viewModel.activeSoundChips
        isEmpty = viewModel.isEmpty
        emptyKind = viewModel.emptyKind
        emptyTitle = viewModel.emptyTitle
        emptyMessage = viewModel.emptyMessage
    }

    func displayClearFilter(_ viewModel: SessionHistoryModels.ClearFilter.ViewModel) {
        groups = viewModel.groups
        totalCount = viewModel.totalCount
        filteredCount = viewModel.filteredCount
        activeFilter = viewModel.activeFilter
        activeSoundChips = viewModel.activeSoundChips
        isEmpty = viewModel.isEmpty
        emptyKind = viewModel.emptyKind
        emptyTitle = viewModel.emptyTitle
        emptyMessage = viewModel.emptyMessage
    }

    func displayOpenSession(_ viewModel: SessionHistoryModels.OpenSession.ViewModel) {
        pendingDetail = viewModel.detail
    }

    func displayFailure(_ viewModel: SessionHistoryModels.Failure.ViewModel) {
        toastMessage = viewModel.toastMessage
        isLoading = false
    }

    func displayLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
    }

    /// Вызывается из View после показа toast-а — чтобы он не «залип».
    func clearToast() {
        toastMessage = nil
    }

    /// Вызывается из View после открытия push-детали.
    func consumePendingDetail() {
        pendingDetail = nil
    }

    // MARK: - Chart / Summary derivations

    /// Точки для Swift Charts: последние `limit` сессий в хронологическом порядке
    /// (старые слева → свежие справа). Берутся из текущих видимых `groups`.
    /// Score у Presenter уже представлен в `scoreText` ("78%") — парсим обратно
    /// в Double, чтобы не тянуть `SessionRecord` в SwiftUI-слой.
    func chartPoints(limit: Int = 14) -> [SessionHistoryChartPoint] {
        guard !groups.isEmpty else { return [] }

        var rows: [(id: String, date: Date, percent: Double)] = []
        let calendar = Calendar.current
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "ru_RU")
        dayFormatter.dateFormat = "yyyy-MM-dd"

        for group in groups {
            for row in group.rows {
                guard let percent = parsePercent(row.scoreText) else { continue }
                guard let date = inferDate(
                    monthGroupId: group.id,
                    dayNumber: row.dayNumber,
                    calendar: calendar
                ) else { continue }
                rows.append((id: row.id, date: date, percent: percent))
            }
        }

        // Хронологически от старых к новым.
        rows.sort { $0.date < $1.date }

        // Оставляем последние N.
        let trimmed = rows.suffix(limit)
        return trimmed.map { row in
            SessionHistoryChartPoint(
                id: row.id,
                date: row.date,
                accuracyPercent: row.percent
            )
        }
    }

    /// Средняя точность в процентах по всем видимым сессиям.
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

    /// Сумма длительности сессий в минутах (по полю `durationText` строки).
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
        // "78%" → 78.0
        let trimmed = text.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
        return Double(trimmed)
    }

    private func parseMinutes(_ text: String) -> Int {
        // "12 мин" → 12
        let digits = text.compactMap { $0.isNumber ? $0 : nil }
        return Int(String(digits)) ?? 0
    }

    private func inferDate(
        monthGroupId: String,
        dayNumber: String,
        calendar: Calendar
    ) -> Date? {
        // monthGroupId: "yyyy-MM"
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
