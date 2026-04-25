import Foundation
import OSLog

// MARK: - HomeTasksBusinessLogic

@MainActor
protocol HomeTasksBusinessLogic: AnyObject {
    func fetch(_ request: HomeTasksModels.Fetch.Request)
    func update(_ request: HomeTasksModels.Update.Request)
    func changeFilter(_ request: HomeTasksModels.ChangeFilter.Request)
    func refresh(_ request: HomeTasksModels.Refresh.Request)
}

// MARK: - HomeTasksInteractor

/// Бизнес-логика экрана «Домашние задания».
///
/// Источник данных — на текущем спринте in-memory seed (5–7 заданий разных типов).
/// На следующем спринте сюда будет подключён `HomeTaskRepository` поверх Realm
/// + listener Firestore. Контракт `presenter` остаётся, поэтому View не пострадает.
@MainActor
final class HomeTasksInteractor: HomeTasksBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any HomeTasksPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "HomeTasks")

    // MARK: - State

    private var allTasks: [HomeTask] = []
    private var activeFilter: TaskFilter = .all

    // MARK: - Init

    init() {
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

        let base: [HomeTask] = [
            HomeTask(
                id: "task-001",
                title: String(localized: "homeTasks.seed.repeatR.title"),
                description: String(localized: "homeTasks.seed.repeatR.desc"),
                targetSound: "Р",
                dueDate: dueIn(days: 1),
                isCompleted: false,
                priority: .high
            ),
            HomeTask(
                id: "task-002",
                title: String(localized: "homeTasks.seed.breathing.title"),
                description: String(localized: "homeTasks.seed.breathing.desc"),
                targetSound: "—",
                dueDate: dueIn(days: 1),
                isCompleted: false,
                priority: .high
            ),
            HomeTask(
                id: "task-003",
                title: String(localized: "homeTasks.seed.bingoSh.title"),
                description: String(localized: "homeTasks.seed.bingoSh.desc"),
                targetSound: "Ш",
                dueDate: dueIn(days: 2),
                isCompleted: false,
                priority: .medium
            ),
            HomeTask(
                id: "task-004",
                title: String(localized: "homeTasks.seed.story.title"),
                description: String(localized: "homeTasks.seed.story.desc"),
                targetSound: "Л",
                dueDate: dueIn(days: 3),
                isCompleted: false,
                priority: .medium
            ),
            HomeTask(
                id: "task-005",
                title: String(localized: "homeTasks.seed.sortingZ.title"),
                description: String(localized: "homeTasks.seed.sortingZ.desc"),
                targetSound: "З",
                dueDate: dueIn(days: 4),
                isCompleted: true,
                priority: .low
            ),
            HomeTask(
                id: "task-006",
                title: String(localized: "homeTasks.seed.mirror.title"),
                description: String(localized: "homeTasks.seed.mirror.desc"),
                targetSound: "К",
                dueDate: nil,
                isCompleted: true,
                priority: .low
            ),
            HomeTask(
                id: "task-007",
                title: String(localized: "homeTasks.seed.minimalPairs.title"),
                description: String(localized: "homeTasks.seed.minimalPairs.desc"),
                targetSound: "С/Ш",
                dueDate: dueIn(days: -1),
                isCompleted: false,
                priority: .high
            )
        ]

        if reseed {
            return base.map { task in
                var copy = task
                copy.isCompleted = false
                return copy
            }
        }
        return base
    }
}
