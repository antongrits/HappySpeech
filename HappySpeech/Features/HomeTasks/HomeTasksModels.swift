import Foundation
import SwiftUI

// MARK: - HomeTasks VIP Models
//
// Доменные модели + transport-слои Request / Response / ViewModel.
// Контур: parent — список заданий, выданных логопедом (или сгенерированных
// LLM-планировщиком после сессии). Фильтры: все / активные / выполненные.

enum HomeTasksModels {

    // MARK: - Fetch

    enum Fetch {
        struct Request: Sendable {
            /// Если true — игнорировать кэш и тянуть свежий список.
            let forceReload: Bool
            init(forceReload: Bool = false) { self.forceReload = forceReload }
        }

        struct Response: Sendable {
            let tasks: [HomeTask]
            let activeFilter: TaskFilter
            let isFromCache: Bool
            init(tasks: [HomeTask], activeFilter: TaskFilter, isFromCache: Bool) {
                self.tasks = tasks
                self.activeFilter = activeFilter
                self.isFromCache = isFromCache
            }
        }

        struct ViewModel: Sendable {
            let visibleTasks: [HomeTaskRow]
            let totalCount: Int
            let activeCount: Int
            let completedCount: Int
            let activeFilter: TaskFilter
            let emptyTitle: String
            let emptyMessage: String
            let isEmpty: Bool
        }
    }

    // MARK: - Update (toggle complete)

    enum Update {
        struct Request: Sendable {
            let taskId: String
        }

        struct Response: Sendable {
            let updatedTask: HomeTask
            let allTasks: [HomeTask]
            let activeFilter: TaskFilter
        }

        struct ViewModel: Sendable {
            let visibleTasks: [HomeTaskRow]
            let totalCount: Int
            let activeCount: Int
            let completedCount: Int
            let activeFilter: TaskFilter
            let toastMessage: String?
            let isEmpty: Bool
        }
    }

    // MARK: - ChangeFilter

    enum ChangeFilter {
        struct Request: Sendable {
            let filter: TaskFilter
        }

        struct Response: Sendable {
            let tasks: [HomeTask]
            let filter: TaskFilter
        }

        struct ViewModel: Sendable {
            let visibleTasks: [HomeTaskRow]
            let totalCount: Int
            let activeCount: Int
            let completedCount: Int
            let activeFilter: TaskFilter
            let isEmpty: Bool
        }
    }

    // MARK: - Refresh

    enum Refresh {
        struct Request: Sendable {}
        struct Response: Sendable {
            let tasks: [HomeTask]
            let activeFilter: TaskFilter
        }
        struct ViewModel: Sendable {
            let visibleTasks: [HomeTaskRow]
            let totalCount: Int
            let activeCount: Int
            let completedCount: Int
            let activeFilter: TaskFilter
            let isEmpty: Bool
        }
    }

    // MARK: - Error

    enum Failure {
        struct Response: Sendable {
            let message: String
        }
        struct ViewModel: Sendable {
            let toastMessage: String
        }
    }
}

// MARK: - Domain types

/// Задание для домашней практики.
/// Создаётся либо логопедом вручную, либо `AdaptivePlannerService` после сессии.
struct HomeTask: Sendable, Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let targetSound: String
    let dueDate: Date?
    var isCompleted: Bool
    let priority: TaskPriority
}

enum TaskPriority: String, Sendable, CaseIterable, Equatable {
    case high
    case medium
    case low

    var displayName: String {
        switch self {
        case .high:   return String(localized: "task.priority.high")
        case .medium: return String(localized: "task.priority.medium")
        case .low:    return String(localized: "task.priority.low")
        }
    }
}

enum TaskFilter: String, Sendable, CaseIterable, Equatable {
    case all
    case active
    case completed

    var displayName: String {
        switch self {
        case .all:       return String(localized: "task.filter.all")
        case .active:    return String(localized: "task.filter.active")
        case .completed: return String(localized: "task.filter.completed")
        }
    }
}

// MARK: - View-ready row

/// Готовая для отображения карточка. Все строки уже отформатированы в Presenter.
struct HomeTaskRow: Sendable, Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let soundBadgeText: String
    let priorityBadgeText: String
    let priority: TaskPriority
    let dueDateText: String?
    let isOverdue: Bool
    let isCompleted: Bool
    let accessibilityLabel: String
    let accessibilityHint: String
}
