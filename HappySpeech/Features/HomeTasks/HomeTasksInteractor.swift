import Foundation
import OSLog

// MARK: - HomeTasksBusinessLogic

@MainActor
protocol HomeTasksBusinessLogic: AnyObject {
    func fetch(_ request: HomeTasksModels.Fetch.Request)
    func update(_ request: HomeTasksModels.Update.Request)
    func changeFilter(_ request: HomeTasksModels.ChangeFilter.Request)
    func refresh(_ request: HomeTasksModels.Refresh.Request)
    func startTask(_ request: HomeTasksModels.StartTask.Request)
    func requestOverdueReminder(_ request: HomeTasksModels.NotifyOverdue.Request)
}

// MARK: - HomeTasksGameRouting

/// Тонкая зависимость, которую Interactor дёргает при запуске упражнения.
/// На текущем этапе — лог-заглушка; позже будет реальный coordinator-роут
/// в шаблон игры по `exerciseType`/`targetSound`.
@MainActor
protocol HomeTasksGameRouting: AnyObject {
    func routeToGame(exerciseType: String, targetSound: String)
}

// MARK: - HomeTasksInteractor

/// Бизнес-логика экрана «Домашние задания».
///
/// Источник данных — на текущем спринте in-memory seed (5–7 заданий разных типов).
/// На следующем спринте сюда будет подключён `HomeTaskRepository` поверх Realm
/// + listener Firestore. Контракт `presenter` остаётся, поэтому View не пострадает.
///
/// Зависимости:
/// * `gameRouter` — заглушка маршрутизации в шаблон игры (передаёт View).
/// * `notificationService` — реальный `NotificationService` (планирует утреннее
///   напоминание для просроченных заданий). Опционален: при `nil` Interactor
///   возвращает `scheduled = false` и Presenter покажет нейтральный toast.
@MainActor
final class HomeTasksInteractor: HomeTasksBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any HomeTasksPresentationLogic)?
    weak var gameRouter: (any HomeTasksGameRouting)?

    private let notificationService: (any NotificationService)?
    private let logger = Logger(subsystem: "ru.happyspeech", category: "HomeTasks")

    // MARK: - State

    private var allTasks: [HomeTask] = []
    private var activeFilter: TaskFilter = .all

    // MARK: - Init

    init(notificationService: (any NotificationService)? = nil) {
        self.notificationService = notificationService
        self.allTasks = Self.makeSeedTasks()
    }

    // MARK: - HomeTasksBusinessLogic

    func fetch(_ request: HomeTasksModels.Fetch.Request) {
        logger.info("fetch forceReload=\(request.forceReload, privacy: .public)")

        if request.forceReload {
            allTasks = Self.makeSeedTasks()
        }

        let response = HomeTasksModels.Fetch.Response(
            tasks: allTasks,
            activeFilter: activeFilter,
            isFromCache: !request.forceReload
        )
        presenter?.presentFetch(response)
    }

    func update(_ request: HomeTasksModels.Update.Request) {
        guard let index = allTasks.firstIndex(where: { $0.id == request.taskId }) else {
            logger.warning("update: task not found id=\(request.taskId, privacy: .public)")
            presenter?.presentFailure(.init(
                message: String(localized: "homeTasks.error.taskNotFound")
            ))
            return
        }

        allTasks[index].isCompleted.toggle()
        // Если отмечаем как выполненное — снимаем флаг "в процессе".
        if allTasks[index].isCompleted {
            allTasks[index].isStarted = false
        }
        let updated = allTasks[index]

        logger.info("toggled task=\(updated.id, privacy: .public) → completed=\(updated.isCompleted, privacy: .public)")

        let response = HomeTasksModels.Update.Response(
            updatedTask: updated,
            allTasks: allTasks,
            activeFilter: activeFilter
        )
        presenter?.presentUpdate(response)
    }

    func changeFilter(_ request: HomeTasksModels.ChangeFilter.Request) {
        guard activeFilter != request.filter else { return }
        activeFilter = request.filter
        logger.info("filter changed → \(request.filter.rawValue, privacy: .public)")

        let response = HomeTasksModels.ChangeFilter.Response(
            tasks: allTasks,
            filter: request.filter
        )
        presenter?.presentChangeFilter(response)
    }

    func refresh(_ request: HomeTasksModels.Refresh.Request) {
        logger.info("refresh requested")
        allTasks = Self.makeSeedTasks(reseed: true)

        let response = HomeTasksModels.Refresh.Response(
            tasks: allTasks,
            activeFilter: activeFilter
        )
        presenter?.presentRefresh(response)
    }

    /// Помечает задачу как «в процессе» и просит router открыть шаблон игры.
    /// Параметры `exerciseType` и `targetSound` берутся из самой задачи —
    /// View не должна знать про эти поля.
    func startTask(_ request: HomeTasksModels.StartTask.Request) {
        guard let index = allTasks.firstIndex(where: { $0.id == request.taskId }) else {
            logger.warning("startTask: task not found id=\(request.taskId, privacy: .public)")
            presenter?.presentFailure(.init(
                message: String(localized: "homeTasks.error.taskNotFound")
            ))
            return
        }

        let task = allTasks[index]
        markStarted(taskId: task.id)

        logger.info("startTask id=\(task.id, privacy: .public) exerciseType=\(task.exerciseType, privacy: .public) sound=\(task.targetSound, privacy: .public)")
        gameRouter?.routeToGame(exerciseType: task.exerciseType, targetSound: task.targetSound)

        presenter?.presentStartTask(.init(
            taskId: task.id,
            exerciseType: task.exerciseType,
            targetSound: task.targetSound
        ))
    }

    /// Запрашивает у NotificationService утреннее напоминание для просроченных
    /// заданий. Если сервиса нет (например, в Preview) — возвращает
    /// `scheduled = false`, и Presenter покажет нейтральный toast.
    func requestOverdueReminder(_ request: HomeTasksModels.NotifyOverdue.Request) {
        guard let service = notificationService else {
            logger.info("notify overdue: notificationService=nil → no-op")
            presenter?.presentNotifyOverdue(.init(
                scheduled: false,
                hour: request.hour,
                minute: request.minute
            ))
            return
        }

        Task { [weak self] in
            guard let self else { return }
            let granted = await service.requestPermission()
            guard granted else {
                self.logger.warning("notify overdue: permission denied")
                self.presenter?.presentNotifyOverdue(.init(
                    scheduled: false,
                    hour: request.hour,
                    minute: request.minute
                ))
                return
            }
            do {
                try await service.scheduleDailyReminder(at: request.hour, minute: request.minute)
                self.logger.info("notify overdue scheduled at \(request.hour, privacy: .public):\(request.minute, privacy: .public)")
                self.presenter?.presentNotifyOverdue(.init(
                    scheduled: true,
                    hour: request.hour,
                    minute: request.minute
                ))
            } catch {
                self.logger.error("notify overdue failed: \(error.localizedDescription, privacy: .public)")
                self.presenter?.presentNotifyOverdue(.init(
                    scheduled: false,
                    hour: request.hour,
                    minute: request.minute
                ))
            }
        }
    }

    // MARK: - Private

    /// Внутренняя пометка «задача начата». Не дёргает Presenter — это делает
    /// `startTask` через `presentStartTask` после успешного route.
    private func markStarted(taskId: String) {
        guard let index = allTasks.firstIndex(where: { $0.id == taskId }) else { return }
        guard !allTasks[index].isCompleted else { return }
        allTasks[index].isStarted = true
    }
}

// MARK: - Seed data

private extension HomeTasksInteractor {

    /// Генерирует список заданий для preview / on-boarding до подключения репозитория.
    /// `reseed=true` оставляет только активные (имитация «обновлено логопедом»).
    static func makeSeedTasks(reseed: Bool = false) -> [HomeTask] {
        let calendar = Calendar.current
        let now = Date()

        func dueIn(days: Int) -> Date? {
            calendar.date(byAdding: .day, value: days, to: now)
        }

        let assignedBy = String(localized: "homeTasks.seed.assignedBy")

        let base: [HomeTask] = [
            HomeTask(
                id: "task-001",
                title: String(localized: "homeTasks.seed.repeatR.title"),
                description: String(localized: "homeTasks.seed.repeatR.desc"),
                targetSound: "Р",
                dueDate: dueIn(days: 0),
                isCompleted: false,
                priority: .high,
                isStarted: true,
                exerciseType: "repeat-after-model",
                estimatedMinutes: 10,
                assignedBy: assignedBy
            ),
            HomeTask(
                id: "task-002",
                title: String(localized: "homeTasks.seed.breathing.title"),
                description: String(localized: "homeTasks.seed.breathing.desc"),
                targetSound: "—",
                dueDate: dueIn(days: 1),
                isCompleted: false,
                priority: .high,
                exerciseType: "breathing",
                estimatedMinutes: 5,
                assignedBy: assignedBy
            ),
            HomeTask(
                id: "task-003",
                title: String(localized: "homeTasks.seed.bingoSh.title"),
                description: String(localized: "homeTasks.seed.bingoSh.desc"),
                targetSound: "Ш",
                dueDate: dueIn(days: 2),
                isCompleted: false,
                priority: .medium,
                exerciseType: "bingo",
                estimatedMinutes: 7,
                assignedBy: assignedBy
            ),
            HomeTask(
                id: "task-004",
                title: String(localized: "homeTasks.seed.story.title"),
                description: String(localized: "homeTasks.seed.story.desc"),
                targetSound: "Л",
                dueDate: dueIn(days: 3),
                isCompleted: false,
                priority: .medium,
                exerciseType: "story-completion",
                estimatedMinutes: 12,
                assignedBy: assignedBy
            ),
            HomeTask(
                id: "task-005",
                title: String(localized: "homeTasks.seed.sortingZ.title"),
                description: String(localized: "homeTasks.seed.sortingZ.desc"),
                targetSound: "З",
                dueDate: dueIn(days: 4),
                isCompleted: true,
                priority: .low,
                exerciseType: "sorting",
                estimatedMinutes: 8,
                assignedBy: assignedBy
            ),
            HomeTask(
                id: "task-006",
                title: String(localized: "homeTasks.seed.mirror.title"),
                description: String(localized: "homeTasks.seed.mirror.desc"),
                targetSound: "К",
                dueDate: nil,
                isCompleted: true,
                priority: .low,
                exerciseType: "articulation-imitation",
                estimatedMinutes: 6,
                assignedBy: assignedBy
            ),
            HomeTask(
                id: "task-007",
                title: String(localized: "homeTasks.seed.minimalPairs.title"),
                description: String(localized: "homeTasks.seed.minimalPairs.desc"),
                targetSound: "С/Ш",
                dueDate: dueIn(days: -1),
                isCompleted: false,
                priority: .high,
                exerciseType: "minimal-pairs",
                estimatedMinutes: 9,
                assignedBy: assignedBy
            )
        ]

        if reseed {
            return base.map { task in
                var copy = task
                copy.isCompleted = false
                copy.isStarted = false
                return copy
            }
        }
        return base
    }
}
