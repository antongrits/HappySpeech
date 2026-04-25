import Foundation
import Observation

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
}
