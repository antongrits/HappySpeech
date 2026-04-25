import Foundation
import Observation

// MARK: - HomeTasksDisplayLogic

/// Контракт между Presenter и SwiftUI-store: Presenter заполняет ViewModel,
/// `display(_:)`-методы пишут поля в `HomeTasksDisplay`, и SwiftUI ре-рендерит UI.
@MainActor
protocol HomeTasksDisplayLogic: AnyObject {
    func displayFetch(_ viewModel: HomeTasksModels.Fetch.ViewModel)
    func displayUpdate(_ viewModel: HomeTasksModels.Update.ViewModel)
    func displayChangeFilter(_ viewModel: HomeTasksModels.ChangeFilter.ViewModel)
    func displayRefresh(_ viewModel: HomeTasksModels.Refresh.ViewModel)
    func displayStartTask(_ viewModel: HomeTasksModels.StartTask.ViewModel)
    func displayNotifyOverdue(_ viewModel: HomeTasksModels.NotifyOverdue.ViewModel)
    func displayFailure(_ viewModel: HomeTasksModels.Failure.ViewModel)
    func displayLoading(_ isLoading: Bool)
}

// MARK: - HomeTasksDisplay (Observable Store)

/// Источник истины для SwiftUI-вью. Никакой бизнес-логики — только состояние.
@Observable
@MainActor
final class HomeTasksDisplay: HomeTasksDisplayLogic {

    // Сгруппированный список секций (overdue → today → thisWeek → later → completed).
    var sections: [HomeTaskSection] = []

    // Счётчики для фильтр-чипов и navbar-бейджа.
    var totalCount: Int = 0
    var activeCount: Int = 0
    var completedCount: Int = 0
    var overdueCount: Int = 0

    // Текущий выбранный фильтр.
    var activeFilter: TaskFilter = .all

    // Empty/loading/error UI.
    var isEmpty: Bool = false
    var emptyTitle: String = ""
    var emptyMessage: String = ""
    var isLoading: Bool = false
    var toastMessage: String?

    // Подсказка показать alert «есть просроченные — напомнить?»
    // Поднимается Presenter'ом в presentFetch, гасится View после отклика пользователя.
    var pendingOverduePrompt: Bool = false

    // MARK: - HomeTasksDisplayLogic

    func displayFetch(_ viewModel: HomeTasksModels.Fetch.ViewModel) {
        sections = viewModel.sections
        totalCount = viewModel.totalCount
        activeCount = viewModel.activeCount
        completedCount = viewModel.completedCount
        overdueCount = viewModel.overdueCount
        activeFilter = viewModel.activeFilter
        emptyTitle = viewModel.emptyTitle
        emptyMessage = viewModel.emptyMessage
        isEmpty = viewModel.isEmpty
        isLoading = false
        pendingOverduePrompt = viewModel.suggestOverduePrompt
    }

    func displayUpdate(_ viewModel: HomeTasksModels.Update.ViewModel) {
        sections = viewModel.sections
        totalCount = viewModel.totalCount
        activeCount = viewModel.activeCount
        completedCount = viewModel.completedCount
        overdueCount = viewModel.overdueCount
        activeFilter = viewModel.activeFilter
        isEmpty = viewModel.isEmpty
        toastMessage = viewModel.toastMessage
    }

    func displayChangeFilter(_ viewModel: HomeTasksModels.ChangeFilter.ViewModel) {
        sections = viewModel.sections
        totalCount = viewModel.totalCount
        activeCount = viewModel.activeCount
        completedCount = viewModel.completedCount
        overdueCount = viewModel.overdueCount
        activeFilter = viewModel.activeFilter
        isEmpty = viewModel.isEmpty
    }

    func displayRefresh(_ viewModel: HomeTasksModels.Refresh.ViewModel) {
        sections = viewModel.sections
        totalCount = viewModel.totalCount
        activeCount = viewModel.activeCount
        completedCount = viewModel.completedCount
        overdueCount = viewModel.overdueCount
        activeFilter = viewModel.activeFilter
        isEmpty = viewModel.isEmpty
        isLoading = false
    }

    func displayStartTask(_ viewModel: HomeTasksModels.StartTask.ViewModel) {
        toastMessage = viewModel.toastMessage
    }

    func displayNotifyOverdue(_ viewModel: HomeTasksModels.NotifyOverdue.ViewModel) {
        toastMessage = viewModel.toastMessage
        pendingOverduePrompt = false
    }

    func displayFailure(_ viewModel: HomeTasksModels.Failure.ViewModel) {
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

    /// Закрывает alert о просроченных, если пользователь нажал «Позже».
    func dismissOverduePrompt() {
        pendingOverduePrompt = false
    }
}
