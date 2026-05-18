import Foundation

// MARK: - AssignedHomeworkModels (Clean Swift: Models)
//
// v29 Фаза 8, Функция 4 «Домашнее задание от логопеда».
//
// Назначаемые задания специалист → ребёнок. Замыкает разрыв «кабинет
// логопеда → дом»: специалист собирает задание из упражнений, ребёнок
// выполняет дома, родитель контролирует. Связь специалист↔ребёнок —
// асинхронная, offline-моделируемая (CLAUDE.md §11): без «живого онлайн».
//
// VIP-модуль; задания хранятся локально через `AssignedHomeworkWorker`.

// MARK: - HomeworkExerciseItem

/// Одно упражнение задания.
public struct HomeworkExerciseItem: Identifiable, Sendable, Equatable, Codable {
    public let id: String
    /// Шаблон упражнения (raw из `TemplateType`).
    public let templateRaw: String
    /// Количество повторов.
    public var repeats: Int
    /// Выполнено повторов.
    public var completedRepeats: Int

    public init(
        id: String = UUID().uuidString,
        templateRaw: String,
        repeats: Int,
        completedRepeats: Int = 0
    ) {
        self.id = id
        self.templateRaw = templateRaw
        self.repeats = repeats
        self.completedRepeats = completedRepeats
    }

    public var isDone: Bool { completedRepeats >= repeats }

    /// Восстановленный тип шаблона.
    public var template: TemplateType? {
        TemplateType(rawValue: templateRaw)
    }
}

// MARK: - HomeworkAssignment

/// Задание, назначенное ребёнку специалистом.
public struct HomeworkAssignment: Identifiable, Sendable, Equatable, Codable {
    public let id: String
    public let childId: String
    public let createdAt: Date
    /// Срок выполнения.
    public let dueDate: Date
    /// Комментарий специалиста родителю.
    public let comment: String
    /// Упражнения задания (2–4 шт.).
    public var exercises: [HomeworkExerciseItem]

    public init(
        id: String = UUID().uuidString,
        childId: String,
        createdAt: Date = Date(),
        dueDate: Date,
        comment: String,
        exercises: [HomeworkExerciseItem]
    ) {
        self.id = id
        self.childId = childId
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.comment = comment
        self.exercises = exercises
    }

    /// Все упражнения выполнены.
    public var isComplete: Bool {
        !exercises.isEmpty && exercises.allSatisfy(\.isDone)
    }

    /// Сколько упражнений завершено.
    public var doneCount: Int {
        exercises.filter(\.isDone).count
    }
}

// MARK: - AssignedHomeworkModels namespace

enum AssignedHomeworkModels {

    // MARK: Load

    enum Load {
        struct Request: Sendable {
            let specialistId: String
        }

        struct Response: Sendable {
            let children: [ChildOption]
            let assignments: [HomeworkAssignment]
            let availableTemplates: [TemplateType]
        }

        struct ChildOption: Identifiable, Sendable, Equatable {
            let id: String
            let name: String
        }

        struct ViewModel: Sendable {
            let title: String
            let children: [ChildOptionViewModel]
            let templates: [TemplateOptionViewModel]
            let assignments: [AssignmentRowViewModel]
            let emptyStateText: String
        }

        struct ChildOptionViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let name: String
        }

        struct TemplateOptionViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let name: String
        }

        struct AssignmentRowViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let childName: String
            let exerciseCountLabel: String
            let dueLabel: String
            let statusLabel: String
            let isComplete: Bool
            let accessibilityLabel: String
        }
    }

    // MARK: Create

    enum Create {
        struct Request: Sendable {
            let childId: String
            let templateRaws: [String]
            let repeatsPerExercise: Int
            let dueInDays: Int
            let comment: String
        }

        struct Response: Sendable {
            let didSucceed: Bool
            let assignment: HomeworkAssignment?
        }

        struct ViewModel: Sendable {
            let didSucceed: Bool
            let message: String
        }
    }
}
