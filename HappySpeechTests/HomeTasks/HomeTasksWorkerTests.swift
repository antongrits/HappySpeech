@testable import HappySpeech
import UserNotifications
import XCTest

// MARK: - HomeTasksWorkerTests
//
// HomeTasksWorker принимает реальный UNUserNotificationCenter.
// Проверяем:
//   - scheduleTaskReminder: noDueDate → false, fireDate in past → false
//   - cancelTaskReminder/cancelAllTaskReminders: не крашит
//   - pendingReminderIds: возвращает только hometask. идентификаторы
//   - scheduleDailyMorningReminder: не бросает для валидных аргументов
//   - HomeTask / TaskPriority domain types

@MainActor
final class HomeTasksWorkerTests: XCTestCase {

    private var sut: HomeTasksWorker!

    override func setUp() {
        super.setUp()
        sut = HomeTasksWorker()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - scheduleTaskReminder: no dueDate → returns false

    func test_scheduleTaskReminder_noDueDate_returnsFalse() async throws {
        let task = HomeTask(
            id: "t-001",
            title: "Задание без даты",
            description: "Описание",
            targetSound: "Р",
            dueDate: nil,
            isCompleted: false,
            priority: .medium
        )
        let result = try await sut.scheduleTaskReminder(for: task, leadTimeMinutes: 60)
        XCTAssertFalse(result, "Задание без dueDate должно вернуть false")
    }

    // MARK: - scheduleTaskReminder: fireDate in past → returns false

    func test_scheduleTaskReminder_fireDateInPast_returnsFalse() async throws {
        let pastDue = Date().addingTimeInterval(-30 * 60)
        let task = HomeTask(
            id: "t-002",
            title: "Просроченное задание",
            description: "Описание",
            targetSound: "Ш",
            dueDate: pastDue,
            isCompleted: false,
            priority: .high
        )
        let result = try await sut.scheduleTaskReminder(for: task, leadTimeMinutes: 60)
        XCTAssertFalse(result, "Если fireDate в прошлом — должно вернуть false")
    }

    // MARK: - cancelTaskReminder: doesn't crash

    func test_cancelTaskReminder_doesNotCrash() async {
        await sut.cancelTaskReminder(taskId: "nonexistent-id")
    }

    // MARK: - cancelAllTaskReminders: doesn't crash

    func test_cancelAllTaskReminders_doesNotCrash() async {
        await sut.cancelAllTaskReminders()
    }

    // MARK: - pendingReminderIds: all have hometask. prefix

    func test_pendingReminderIds_allHavePrefix() async {
        let ids = await sut.pendingReminderIds()
        XCTAssertTrue(ids.allSatisfy { $0.hasPrefix("hometask.") },
                      "pendingReminderIds должен возвращать только hometask. идентификаторы")
    }

    // MARK: - scheduleDailyMorningReminder: valid args → no throw

    func test_scheduleDailyMorningReminder_doesNotThrow() async {
        do {
            try await sut.scheduleDailyMorningReminder(hour: 9, minute: 0)
        } catch {
            XCTFail("scheduleDailyMorningReminder не должен бросать ошибку: \(error)")
        }
    }

    // MARK: - scheduleTaskReminder: future date for high priority

    func test_scheduleTaskReminder_futureDateHighPriority_doesNotThrow() async {
        let futureDate = Date().addingTimeInterval(3600)
        let task = HomeTask(
            id: "t-high",
            title: "Срочное задание",
            description: "Описание",
            targetSound: "Л",
            dueDate: futureDate,
            isCompleted: false,
            priority: .high
        )
        do {
            _ = try await sut.scheduleTaskReminder(for: task, leadTimeMinutes: 30)
        } catch {
            XCTFail("Неожиданная ошибка: \(error)")
        }
    }

    // MARK: - HomeTask domain model: equatable

    func test_homeTask_equatable_sameAllFields() {
        let t1 = HomeTask(id: "x", title: "А", description: "", targetSound: "Р",
                          dueDate: nil, isCompleted: false, priority: .low)
        let t2 = HomeTask(id: "x", title: "А", description: "", targetSound: "Р",
                          dueDate: nil, isCompleted: false, priority: .low)
        XCTAssertEqual(t1, t2)
    }

    func test_homeTask_notEqual_differentId() {
        let t1 = HomeTask(id: "a", title: "А", description: "", targetSound: "Р",
                          dueDate: nil, isCompleted: false, priority: .low)
        let t2 = HomeTask(id: "b", title: "А", description: "", targetSound: "Р",
                          dueDate: nil, isCompleted: false, priority: .low)
        XCTAssertNotEqual(t1, t2)
    }

    // MARK: - TaskPriority rawValues

    func test_taskPriority_highRawValue() {
        XCTAssertEqual(TaskPriority.high.rawValue, "high")
    }

    func test_taskPriority_mediumRawValue() {
        XCTAssertEqual(TaskPriority.medium.rawValue, "medium")
    }

    func test_taskPriority_lowRawValue() {
        XCTAssertEqual(TaskPriority.low.rawValue, "low")
    }

    // MARK: - TaskFilter rawValues

    func test_taskFilter_allCases_count() {
        XCTAssertEqual(TaskFilter.allCases.count, 3)
    }
}
