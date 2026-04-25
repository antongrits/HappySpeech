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
    func displayFailure(_ viewModel: HomeTasksModels.Failure.ViewModel)
    func displayLoading(_ isLoading: Bool)
}

// MARK: - HomeTasksDisplay (Observable Store)

/// Источник истины для SwiftUI-вью. Никакой бизнес-логики — только состояние.
@Observable
@MainActor
final class HomeTasksDisplay: HomeTasksDisplayLogic {

    // Список карточек, уже отфильтрованный Presenter'ом.
    var visibleTasks: [HomeTaskRow] = []

    // Счётчики для фильтр-чипов и navbar-бейджа.
    var totalCount: Int = 0
    var activeCount: Int = 0
    var completedCount: Int = 0

    // Текущий выбранный фильтр.
    var activeFilter: TaskFilter = .all

    // Empty/loading/error UI.
    var isEmpty: Bool = false
    var emptyTitle: String = ""
    var emptyMessage: String = ""
    var isLoading: Bool = false
    var toastMessage: String?

    // MARK: - HomeTasksDisplayLogic

    func displayFetch(_ viewModel: HomeTasksModels.Fetch.ViewModel) {
        visibleTasks = viewModel.visibleTasks
        totalCount = viewModel.totalCount
        activeCount = viewModel.activeCount
        completedCount = viewModel.completedCount
        activeFilter = viewModel.activeFilter
        emptyTitle = viewModel.emptyTitle
        emptyMessage = viewModel.emptyMessage
        isEmpty = viewModel.isEmpty
        isLoading = false
    }

    func displayUpdate(_ viewModel: HomeTasksModels.Update.ViewModel) {
        visibleTasks = viewModel.visibleTasks
        totalCount = viewModel.totalCount
        activeCount = viewModel.activeCount
        completedCount = viewModel.completedCount
        activeFilter = viewModel.activeFilter
        isEmpty = viewModel.isEmpty
        toastMessage = viewModel.toastMessage
    }

    func displayChangeFilter(_ viewModel: HomeTasksModels.ChangeFilter.ViewModel) {
        visibleTasks = viewModel.visibleTasks
        totalCount = viewModel.totalCount
        activeCount = viewModel.activeCount
        completedCount = viewModel.completedCount
        activeFilter = viewModel.activeFilter
        isEmpty = viewModel.isEmpty
    }

    func displayRefresh(_ viewModel: HomeTasksModels.Refresh.ViewModel) {
        visibleTasks = viewModel.visibleTasks
        totalCount = viewModel.totalCount
        activeCount = viewModel.activeCount
        completedCount = viewModel.completedCount
        activeFilter = viewModel.activeFilter
        isEmpty = viewModel.isEmpty
        isLoading = false
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
}
