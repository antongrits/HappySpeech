import Foundation
import OSLog

// MARK: - HomeTasksPresentationLogic

@MainActor
protocol HomeTasksPresentationLogic: AnyObject {
    func presentFetch(_ response: HomeTasksModels.Fetch.Response)
    func presentUpdate(_ response: HomeTasksModels.Update.Response)
    func presentChangeFilter(_ response: HomeTasksModels.ChangeFilter.Response)
    func presentRefresh(_ response: HomeTasksModels.Refresh.Response)
    func presentStartTask(_ response: HomeTasksModels.StartTask.Response)
    func presentNotifyOverdue(_ response: HomeTasksModels.NotifyOverdue.Response)
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
        let stats = computeStats(response.tasks)
        let viewModel = HomeTasksModels.Fetch.ViewModel(
            sections: makeSections(from: visible),
            totalCount: stats.total,
            activeCount: stats.active,
            completedCount: stats.completed,
            overdueCount: stats.overdue,
            activeFilter: response.activeFilter,
            emptyTitle: emptyTitle(for: response.activeFilter),
            emptyMessage: emptyMessage(for: response.activeFilter),
            isEmpty: visible.isEmpty,
            suggestOverduePrompt: stats.overdue > 0
        )
        display?.displayFetch(viewModel)
    }

    func presentUpdate(_ response: HomeTasksModels.Update.Response) {
        let visible = filteredAndSorted(response.allTasks, by: response.activeFilter)
        let stats = computeStats(response.allTasks)
        let toast: String? = response.updatedTask.isCompleted
            ? String(localized: "homeTasks.toast.completed")
            : String(localized: "homeTasks.toast.reopened")

        let viewModel = HomeTasksModels.Update.ViewModel(
            sections: makeSections(from: visible),
            totalCount: stats.total,
            activeCount: stats.active,
            completedCount: stats.completed,
            overdueCount: stats.overdue,
            activeFilter: response.activeFilter,
            toastMessage: toast,
            isEmpty: visible.isEmpty
        )
        display?.displayUpdate(viewModel)
    }

    func presentChangeFilter(_ response: HomeTasksModels.ChangeFilter.Response) {
        let visible = filteredAndSorted(response.tasks, by: response.filter)
        let stats = computeStats(response.tasks)
        let viewModel = HomeTasksModels.ChangeFilter.ViewModel(
            sections: makeSections(from: visible),
            totalCount: stats.total,
            activeCount: stats.active,
            completedCount: stats.completed,
            overdueCount: stats.overdue,
            activeFilter: response.filter,
            isEmpty: visible.isEmpty
        )
        display?.displayChangeFilter(viewModel)
    }

    func presentRefresh(_ response: HomeTasksModels.Refresh.Response) {
        let visible = filteredAndSorted(response.tasks, by: response.activeFilter)
        let stats = computeStats(response.tasks)
        let viewModel = HomeTasksModels.Refresh.ViewModel(
            sections: makeSections(from: visible),
            totalCount: stats.total,
            activeCount: stats.active,
            completedCount: stats.completed,
            overdueCount: stats.overdue,
            activeFilter: response.activeFilter,
            isEmpty: visible.isEmpty
        )
        display?.displayRefresh(viewModel)
    }

    func presentStartTask(_ response: HomeTasksModels.StartTask.Response) {
        logger.info("start task=\(response.taskId, privacy: .public) → \(response.exerciseType, privacy: .public)/\(response.targetSound, privacy: .public)")
        let viewModel = HomeTasksModels.StartTask.ViewModel(
            toastMessage: String(localized: "homeTasks.toast.started"),
            exerciseType: response.exerciseType,
            targetSound: response.targetSound
        )
        display?.displayStartTask(viewModel)
    }

    func presentNotifyOverdue(_ response: HomeTasksModels.NotifyOverdue.Response) {
        let toast: String
        if response.scheduled {
            let timeText = String(format: "%02d:%02d", response.hour, response.minute)
            toast = String(
                format: String(localized: "homeTasks.toast.notifyScheduled"),
                timeText
            )
        } else {
            toast = String(localized: "homeTasks.toast.notifyFailed")
        }
        display?.displayNotifyOverdue(.init(toastMessage: toast))
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
            case let (left?, right?): return left < right
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
            subtitle: makeSubtitle(for: task),
            soundBadgeText: soundBadge,
            priorityBadgeText: task.priority.displayName,
            priority: task.priority,
            dueDateText: dueText,
            isOverdue: isOverdue,
            isCompleted: task.isCompleted,
            isStarted: task.isStarted,
            exerciseType: task.exerciseType,
            targetSound: task.targetSound,
            startButtonTitle: makeStartButtonTitle(for: task),
            accessibilityLabel: label,
            accessibilityHint: hint
        )
    }

    /// Подзаголовок карточки: «Звук Р · ~10 мин · от Марины Ивановны».
    /// Опускает сегменты, если они пусты, чтобы не было лишних точек.
    private func makeSubtitle(for task: HomeTask) -> String {
        var segments: [String] = []
        if task.targetSound != "—" {
            segments.append(String(
                format: String(localized: "homeTasks.subtitle.sound"),
                task.targetSound
            ))
        }
        if task.estimatedMinutes > 0 {
            segments.append(String(
                format: String(localized: "homeTasks.subtitle.minutes"),
                task.estimatedMinutes
            ))
        }
        if !task.assignedBy.isEmpty {
            segments.append(String(
                format: String(localized: "homeTasks.subtitle.assignedBy"),
                task.assignedBy
            ))
        }
        return segments.joined(separator: " · ")
    }

    /// Контекстный заголовок CTA: «Начать», «Продолжить», «Повторить».
    private func makeStartButtonTitle(for task: HomeTask) -> String {
        if task.isCompleted {
            return String(localized: "homeTasks.action.repeat")
        }
        if task.isStarted {
            return String(localized: "homeTasks.action.continue")
        }
        return String(localized: "homeTasks.action.start")
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

    // MARK: - Section grouping

    /// Распределяет уже отфильтрованные задачи по секциям дедлайна.
    /// Порядок секций фиксирован: overdue → today → thisWeek → later → completed.
    private func makeSections(from tasks: [HomeTask]) -> [HomeTaskSection] {
        var buckets: [TaskGroupKind: [HomeTask]] = [:]
        for task in tasks {
            buckets[bucket(for: task), default: []].append(task)
        }
        return TaskGroupKind.allCases.compactMap { kind in
            guard let group = buckets[kind], !group.isEmpty else { return nil }
            return HomeTaskSection(
                kind: kind,
                title: String(localized: kind.titleKey),
                rows: group.map(makeRow)
            )
        }
    }

    /// Маппинг задачи на bucket. Сначала смотрим, выполнена ли,
    /// потом анализируем дедлайн относительно текущего дня.
    private func bucket(for task: HomeTask) -> TaskGroupKind {
        if task.isCompleted { return .completed }
        guard let due = task.dueDate else { return .later }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayDiff = calendar.dateComponents(
            [.day], from: today, to: calendar.startOfDay(for: due)
        ).day ?? 0

        switch dayDiff {
        case ..<0:    return .overdue
        case 0:       return .today
        case 1...7:   return .thisWeek
        default:      return .later
        }
    }

    // MARK: - Stats

    /// Сводные счётчики для toolbar-бейджа и chips.
    private struct Stats {
        let total: Int
        let active: Int
        let completed: Int
        let overdue: Int
    }

    private func computeStats(_ tasks: [HomeTask]) -> Stats {
        var active = 0
        var completed = 0
        var overdue = 0
        let today = Calendar.current.startOfDay(for: Date())
        for task in tasks {
            if task.isCompleted {
                completed += 1
            } else {
                active += 1
                if let due = task.dueDate, due < today {
                    overdue += 1
                }
            }
        }
        return Stats(total: tasks.count, active: active, completed: completed, overdue: overdue)
    }
}
