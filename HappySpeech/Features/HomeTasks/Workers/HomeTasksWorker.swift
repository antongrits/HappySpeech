import Foundation
import OSLog
import UserNotifications

// MARK: - HomeTasksWorkerProtocol

/// Изолированный сервисный слой — всё взаимодействие с UNUserNotificationCenter
/// и локальной обработкой задач вынесено сюда из Interactor'а.
/// Interactor остаётся чистым: принимает запрос, вызывает Worker, передаёт Response в Presenter.
@MainActor
protocol HomeTasksWorkerProtocol: AnyObject {
    /// Планирует локальное push-уведомление за `leadTimeMinutes` минут до дедлайна.
    /// Возвращает `true` если уведомление успешно запланировано.
    func scheduleTaskReminder(
        for task: HomeTask,
        leadTimeMinutes: Int
    ) async throws -> Bool

    /// Снимает запланированное уведомление для задачи (при отметке "выполнено").
    func cancelTaskReminder(taskId: String) async

    /// Снимает все уведомления HomeTasks.
    func cancelAllTaskReminders() async

    /// Возвращает идентификаторы всех запланированных уведомлений.
    func pendingReminderIds() async -> [String]

    /// Планирует ежедневное утреннее напоминание.
    func scheduleDailyMorningReminder(hour: Int, minute: Int) async throws
}

// MARK: - HomeTasksWorker

/// Конкретная реализация поверх `UNUserNotificationCenter`.
/// Все методы изолированы на `@MainActor` (как и сам Interactor),
/// чтобы не создавать лишних Task-переходов.
@MainActor
final class HomeTasksWorker: HomeTasksWorkerProtocol {

    // MARK: - Constants

    private enum NotificationCategory {
        static let homeTask = "HOME_TASK_REMINDER"
        static let dailyMorning = "HOME_TASK_DAILY_MORNING"
    }

    private enum UserInfoKey {
        static let taskId = "taskId"
        static let taskTitle = "taskTitle"
    }

    private let center: UNUserNotificationCenter
    private let logger = Logger(subsystem: "ru.happyspeech", category: "HomeTasksWorker")

    // MARK: - Init

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        registerCategories()
    }

    // MARK: - HomeTasksWorkerProtocol

    func scheduleTaskReminder(
        for task: HomeTask,
        leadTimeMinutes: Int
    ) async throws -> Bool {
        guard let dueDate = task.dueDate else {
            logger.info("scheduleTaskReminder: task \(task.id, privacy: .public) has no dueDate — skip")
            return false
        }

        // Вычисляем момент срабатывания — за leadTimeMinutes до дедлайна
        let fireDate = dueDate.addingTimeInterval(TimeInterval(-leadTimeMinutes * 60))
        guard fireDate > Date() else {
            logger.warning("scheduleTaskReminder: fire date in the past for task \(task.id, privacy: .public)")
            return false
        }

        let content = makeContent(for: task)
        let trigger = makeTrigger(from: fireDate)
        let identifier = reminderIdentifier(for: task.id)

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        try await center.add(request)
        logger.info("scheduleTaskReminder: scheduled id=\(identifier, privacy: .public) fireDate=\(fireDate, privacy: .public)")
        return true
    }

    func cancelTaskReminder(taskId: String) async {
        let identifier = reminderIdentifier(for: taskId)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        logger.info("cancelTaskReminder: removed id=\(identifier, privacy: .public)")
    }

    func cancelAllTaskReminders() async {
        let pending = await center.pendingNotificationRequests()
        let homeTaskIds = pending
            .filter { $0.identifier.hasPrefix("hometask.") }
            .map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: homeTaskIds)
        logger.info("cancelAllTaskReminders: removed \(homeTaskIds.count, privacy: .public) notifications")
    }

    func pendingReminderIds() async -> [String] {
        let pending = await center.pendingNotificationRequests()
        return pending
            .filter { $0.identifier.hasPrefix("hometask.") }
            .map(\.identifier)
    }

    func scheduleDailyMorningReminder(hour: Int, minute: Int) async throws {
        // Убираем предыдущее ежедневное напоминание
        center.removePendingNotificationRequests(
            withIdentifiers: [NotificationCategory.dailyMorning]
        )

        let content = UNMutableNotificationContent()
        content.title = String(localized: "homeTasks.notify.morning.title")
        content.body = String(localized: "homeTasks.notify.morning.body")
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.dailyMorning

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        let request = UNNotificationRequest(
            identifier: NotificationCategory.dailyMorning,
            content: content,
            trigger: trigger
        )
        try await center.add(request)
        logger.info("scheduleDailyMorningReminder: scheduled at \(hour, privacy: .public):\(minute, privacy: .public)")
    }

    // MARK: - Private helpers

    private func reminderIdentifier(for taskId: String) -> String {
        "hometask.\(taskId)"
    }

    private func makeContent(for task: HomeTask) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()

        // Заголовок с приоритетом
        let priorityEmoji: String
        switch task.priority {
        case .high:   priorityEmoji = "!"
        case .medium: priorityEmoji = ""
        case .low:    priorityEmoji = ""
        }

        content.title = priorityEmoji.isEmpty
            ? task.title
            : "\(priorityEmoji) \(task.title)"

        content.body = String(
            format: String(localized: "homeTasks.notify.task.body"),
            task.targetSound,
            task.estimatedMinutes
        )

        content.sound = .default
        content.categoryIdentifier = NotificationCategory.homeTask
        content.userInfo = [
            UserInfoKey.taskId: task.id,
            UserInfoKey.taskTitle: task.title
        ]

        // Группировка — все задания в одной thread группе
        content.threadIdentifier = "ru.happyspeech.hometasks"
        return content
    }

    private func makeTrigger(from date: Date) -> UNCalendarNotificationTrigger {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    private func registerCategories() {
        // Действие "Начать упражнение" прямо из уведомления
        let startAction = UNNotificationAction(
            identifier: "START_EXERCISE",
            title: String(localized: "homeTasks.notify.action.start"),
            options: [.foreground]
        )
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: String(localized: "homeTasks.notify.action.dismiss"),
            options: []
        )

        let category = UNNotificationCategory(
            identifier: NotificationCategory.homeTask,
            actions: [startAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        center.setNotificationCategories([category])
    }
}
