import Foundation

// MARK: - HomeTasks VIP Models
//
// Доменные модели + transport-слои Request / Response / ViewModel.
// Контур: parent — список заданий, выданных логопедом (или сгенерированных
// LLM-планировщиком после сессии). Фильтры: все / активные / выполненные.
//
// Группировка по дедлайну (Presenter): просрочено → сегодня → на этой неделе
// → позже → выполнено. Работает поверх любого активного фильтра.
//
// Никаких импортов SwiftUI — Models остаются чистым доменом, цвета/иконки
// для статуса формирует Presenter.

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
            let sections: [HomeTaskSection]
            let totalCount: Int
            let activeCount: Int
            let completedCount: Int
            let overdueCount: Int
            let activeFilter: TaskFilter
            let emptyTitle: String
            let emptyMessage: String
            let isEmpty: Bool
            let suggestOverduePrompt: Bool
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
            let sections: [HomeTaskSection]
            let totalCount: Int
            let activeCount: Int
            let completedCount: Int
            let overdueCount: Int
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
            let sections: [HomeTaskSection]
            let totalCount: Int
            let activeCount: Int
            let completedCount: Int
            let overdueCount: Int
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
            let sections: [HomeTaskSection]
            let totalCount: Int
            let activeCount: Int
            let completedCount: Int
            let overdueCount: Int
            let activeFilter: TaskFilter
            let isEmpty: Bool
        }
    }

    // MARK: - StartTask

    /// Запрос на запуск упражнения из карточки задания.
    /// Interactor помечает задание как «в процессе» (markStarted) и просит
    /// router открыть соответствующий шаблон игры.
    enum StartTask {
        struct Request: Sendable {
            let taskId: String
        }

        struct Response: Sendable {
            let taskId: String
            let exerciseType: String
            let targetSound: String
        }

        struct ViewModel: Sendable {
            let toastMessage: String
            let exerciseType: String
            let targetSound: String
        }
    }

    // MARK: - NotifyOverdue

    /// Заглушка-обращение к NotificationService: «напомни завтра утром».
    enum NotifyOverdue {
        struct Request: Sendable {
            /// Часы (0–23) для утреннего напоминания.
            let hour: Int
            /// Минуты (0–59).
            let minute: Int
            init(hour: Int = 9, minute: Int = 30) {
                self.hour = hour
                self.minute = minute
            }
        }

        struct Response: Sendable {
            let scheduled: Bool
            let hour: Int
            let minute: Int
        }

        struct ViewModel: Sendable {
            let toastMessage: String
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
    var isStarted: Bool
    let priority: TaskPriority
    /// Идентификатор шаблона игры — используется router'ом для навигации.
    /// Допустимые значения: см. `speech-games-tz.md` (`repeat-after-model`,
    /// `listen-and-choose`, `breathing`, `bingo`, `story-completion`,
    /// `sorting`, `articulation-imitation`, `minimal-pairs` и т.п.).
    let exerciseType: String
    /// Оценка длительности в минутах — для подзаголовка карточки.
    let estimatedMinutes: Int
    /// Имя специалиста (или «Адаптивный план»), кто назначил задание.
    let assignedBy: String

    init(
        id: String,
        title: String,
        description: String,
        targetSound: String,
        dueDate: Date?,
        isCompleted: Bool,
        priority: TaskPriority,
        isStarted: Bool = false,
        exerciseType: String = "repeat-after-model",
        estimatedMinutes: Int = 8,
        assignedBy: String = ""
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.targetSound = targetSound
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.isStarted = isStarted
        self.priority = priority
        self.exerciseType = exerciseType
        self.estimatedMinutes = estimatedMinutes
        self.assignedBy = assignedBy
    }
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
    let subtitle: String          // "Звук Р · ~10 мин · от Марины Ивановны"
    let soundBadgeText: String
    let priorityBadgeText: String
    let priority: TaskPriority
    let dueDateText: String?
    let isOverdue: Bool
    let isCompleted: Bool
    let isStarted: Bool
    let exerciseType: String
    let targetSound: String
    let startButtonTitle: String  // "Начать" / "Продолжить" / "Повторить"
    let accessibilityLabel: String
    let accessibilityHint: String
}

// MARK: - Section grouping

/// Группа карточек по дедлайну. Presenter формирует упорядоченный список секций.
struct HomeTaskSection: Sendable, Identifiable, Equatable {
    /// `kind.rawValue` — стабильный идентификатор для SwiftUI ForEach.
    var id: String { kind.rawValue }
    let kind: TaskGroupKind
    let title: String
    let rows: [HomeTaskRow]
}

/// Корневой признак группировки. Порядок enum — это порядок отображения.
enum TaskGroupKind: String, Sendable, CaseIterable, Equatable {
    case overdue   = "overdue"     // дедлайн в прошлом, не выполнено
    case today     = "today"       // дедлайн = сегодня
    case thisWeek  = "thisWeek"    // дедлайн в пределах ближайших 7 дней
    case later     = "later"       // дедлайн позже / не задан
    case completed = "completed"   // выполнено

    /// Ключ локализации для заголовка секции.
    var titleKey: String.LocalizationValue {
        switch self {
        case .overdue:   return "homeTasks.group.overdue"
        case .today:     return "homeTasks.group.today"
        case .thisWeek:  return "homeTasks.group.thisWeek"
        case .later:     return "homeTasks.group.later"
        case .completed: return "homeTasks.group.completed"
        }
    }
}
