import Foundation
import OSLog

// MARK: - HomeTasksPresentationLogic

@MainActor
protocol HomeTasksPresentationLogic: AnyObject {
    func presentFetch(_ response: HomeTasksModels.Fetch.Response)
    func presentUpdate(_ response: HomeTasksModels.Update.Response)
    func presentChangeFilter(_ response: HomeTasksModels.ChangeFilter.Response)
    func presentRefresh(_ response: HomeTasksModels.Refresh.Response)
    func presentFailure(_ response: HomeTasksModels.Failure.Response)
}

// MARK: - HomeTasksPresenter

/// Преобразует `Response` от Interactor'а в `ViewModel`, готовую к показу.
/// Здесь — все локализованные строки, форматирование дат, accessibility-метки.
@MainActor
final class HomeTasksPresenter: HomeTasksPresentationLogic {

    weak var display: (any HomeTasksDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "HomeTasksPresenter")

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "d MMMM"
        return df
    }()

    // MARK: - PresentationLogic

    func presentFetch(_ response: HomeTasksModels.Fetch.Response) {
        let visible = filteredAndSorted(response.tasks, by: response.activeFilter)
        let viewModel = HomeTasksModels.Fetch.ViewModel(
            visibleTasks: visible.map(makeRow),
            totalCount: response.tasks.count,
            activeCount: response.tasks.filter { !$0.isCompleted }.count,
            completedCount: response.tasks.filter(\.isCompleted).count,
            activeFilter: response.activeFilter,
            emptyTitle: emptyTitle(for: response.activeFilter),
            emptyMessage: emptyMessage(for: response.activeFilter),
            isEmpty: visible.isEmpty
        )
        display?.displayFetch(viewModel)
    }

    func presentUpdate(_ response: HomeTasksModels.Update.Response) {
        let visible = filteredAndSorted(response.allTasks, by: response.activeFilter)
        let toast: String? = response.updatedTask.isCompleted
            ? String(localized: "homeTasks.toast.completed")
            : String(localized: "homeTasks.toast.reopened")

        let viewModel = HomeTasksModels.Update.ViewModel(
            visibleTasks: visible.map(makeRow),
            totalCount: response.allTasks.count,
            activeCount: response.allTasks.filter { !$0.isCompleted }.count,
            completedCount: response.allTasks.filter(\.isCompleted).count,
            activeFilter: response.activeFilter,
            toastMessage: toast,
            isEmpty: visible.isEmpty
        )
        display?.displayUpdate(viewModel)
    }

    func presentChangeFilter(_ response: HomeTasksModels.ChangeFilter.Response) {
        let visible = filteredAndSorted(response.tasks, by: response.filter)
        let viewModel = HomeTasksModels.ChangeFilter.ViewModel(
            visibleTasks: visible.map(makeRow),
            totalCount: response.tasks.count,
            activeCount: response.tasks.filter { !$0.isCompleted }.count,
            completedCount: response.tasks.filter(\.isCompleted).count,
            activeFilter: response.filter,
            isEmpty: visible.isEmpty
        )
        display?.displayChangeFilter(viewModel)
    }

    func presentRefresh(_ response: HomeTasksModels.Refresh.Response) {
        let visible = filteredAndSorted(response.tasks, by: response.activeFilter)
        let viewModel = HomeTasksModels.Refresh.ViewModel(
            visibleTasks: visible.map(makeRow),
            totalCount: response.tasks.count,
            activeCount: response.tasks.filter { !$0.isCompleted }.count,
            completedCount: response.tasks.filter(\.isCompleted).count,
            activeFilter: response.activeFilter,
            isEmpty: visible.isEmpty
        )
        display?.displayRefresh(viewModel)
    }

    func presentFailure(_ response: HomeTasksModels.Failure.Response) {
        logger.error("failure: \(response.message, privacy: .public)")
        display?.displayFailure(.init(toastMessage: response.message))
    }

    // MARK: - Helpers

    private func filteredAndSorted(_ tasks: [HomeTask], by filter: TaskFilter) -> [HomeTask] {
        let filtered: [HomeTask]
        switch filter {
        case .all:       filtered = tasks
        case .active:    filtered = tasks.filter { !$0.isCompleted }
        case .completed: filtered = tasks.filter(\.isCompleted)
        }

        return filtered.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted && rhs.isCompleted
            }
            if lhs.priority != rhs.priority {
                return priorityOrder(lhs.priority) < priorityOrder(rhs.priority)
            }
            switch (lhs.dueDate, rhs.dueDate) {
            case let (l?, r?): return l < r
            case (_?, nil):    return true
            case (nil, _?):    return false
            case (nil, nil):   return lhs.id < rhs.id
            }
        }
    }

    private func priorityOrder(_ priority: TaskPriority) -> Int {
        switch priority {
        case .high:   return 0
        case .medium: return 1
        case .low:    return 2
        }
    }

    private func makeRow(_ task: HomeTask) -> HomeTaskRow {
        let dueText: String?
        let isOverdue: Bool
        if let due = task.dueDate {
            let calendar = Calendar.current
            let dayDiff = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: Date()),
                to: calendar.startOfDay(for: due)
            ).day ?? 0
            switch dayDiff {
            case ..<0:
                dueText = String(localized: "homeTasks.dueDate.overdue")
                isOverdue = !task.isCompleted
            case 0:
                dueText = String(localized: "homeTasks.dueDate.today")
                isOverdue = false
            case 1:
                dueText = String(localized: "homeTasks.dueDate.tomorrow")
                isOverdue = false
            default:
                dueText = Self.dateFormatter.string(from: due)
                isOverdue = false
            }
        } else {
            dueText = nil
            isOverdue = false
        }

        let soundBadge: String
        if task.targetSound == "—" {
            soundBadge = String(localized: "homeTasks.badge.noSound")
        } else {
            soundBadge = task.targetSound
        }

        let statusText = task.isCompleted
            ? String(localized: "homeTasks.a11y.statusCompleted")
            : String(localized: "homeTasks.a11y.statusActive")

        let label = "\(task.title). \(task.description). \(statusText)"
        let hint = task.isCompleted
            ? String(localized: "homeTasks.a11y.hintReopen")
            : String(localized: "homeTasks.a11y.hintComplete")

        return HomeTaskRow(
            id: task.id,
            title: task.title,
            description: task.description,
            soundBadgeText: soundBadge,
            priorityBadgeText: task.priority.displayName,
            priority: task.priority,
            dueDateText: dueText,
            isOverdue: isOverdue,
            isCompleted: task.isCompleted,
            accessibilityLabel: label,
            accessibilityHint: hint
        )
    }

    private func emptyTitle(for filter: TaskFilter) -> String {
        switch filter {
        case .all:       return String(localized: "homeTasks.empty.all.title")
        case .active:    return String(localized: "homeTasks.empty.active.title")
        case .completed: return String(localized: "homeTasks.empty.completed.title")
        }
    }

    private func emptyMessage(for filter: TaskFilter) -> String {
        switch filter {
        case .all:       return String(localized: "homeTasks.empty.all.message")
        case .active:    return String(localized: "homeTasks.empty.active.message")
        case .completed: return String(localized: "homeTasks.empty.completed.message")
        }
    }
}
