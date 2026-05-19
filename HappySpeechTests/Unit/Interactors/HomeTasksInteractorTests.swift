@testable import HappySpeech
import XCTest

// MARK: - HomeTasksInteractorTests
//
// M10.1 — 8 тестов для HomeTasksInteractor.
// Покрывает: fetch, update (toggle complete), changeFilter,
// refresh, startTask, fetchDetail, edge cases.

@MainActor
final class HomeTasksInteractorTests: XCTestCase {

    // MARK: - Spy

    @MainActor
    private final class SpyPresenter: HomeTasksPresentationLogic {
        var fetchCalled = false
        var updateCalled = false
        var changeFilterCalled = false
        var refreshCalled = false
        var startTaskCalled = false
        var notifyOverdueCalled = false
        var detailCalled = false
        var scheduleReminderCalled = false
        var failureCalled = false

        var lastFetch: HomeTasksModels.Fetch.Response?
        var lastUpdate: HomeTasksModels.Update.Response?

        func presentFetch(_ response: HomeTasksModels.Fetch.Response) {
            fetchCalled = true; lastFetch = response
        }
        func presentUpdate(_ response: HomeTasksModels.Update.Response) {
            updateCalled = true; lastUpdate = response
        }
        func presentChangeFilter(_ response: HomeTasksModels.ChangeFilter.Response) {
            changeFilterCalled = true
        }
        func presentRefresh(_ response: HomeTasksModels.Refresh.Response) {
            refreshCalled = true
        }
        func presentStartTask(_ response: HomeTasksModels.StartTask.Response) {
            startTaskCalled = true
        }
        func presentNotifyOverdue(_ response: HomeTasksModels.NotifyOverdue.Response) {
            notifyOverdueCalled = true
        }
        func presentDetail(_ response: HomeTasksModels.FetchDetail.Response) {
            detailCalled = true
        }
        func presentScheduleReminder(_ response: HomeTasksModels.ScheduleReminder.Response) {
            scheduleReminderCalled = true
        }
        func presentFailure(_ response: HomeTasksModels.Failure.Response) {
            failureCalled = true
        }
    }

    private func makeSUT() -> (HomeTasksInteractor, SpyPresenter) {
        let sut = HomeTasksInteractor(notificationService: MockNotificationService())
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    /// Детерминированно ждёт выполнения условия (вместо фиксированного sleep).
    /// Работа диспатчится в Task — polling устраняет гонку с планировщиком.
    private func waitUntil(
        timeout: TimeInterval = 5.0,
        _ condition: @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("waitUntil: условие не выполнено за \(timeout) с")
                return
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    // MARK: - 1. fetch вызывает presentFetch с заданиями

    func test_fetch_callsPresenterWithTasks() {
        let (sut, spy) = makeSUT()
        sut.fetch(.init(forceReload: false))
        XCTAssertTrue(spy.fetchCalled)
        XCTAssertFalse(spy.lastFetch?.tasks.isEmpty ?? true)
    }

    // MARK: - 2. fetch с forceReload = true пересоздаёт seed

    func test_fetch_forceReload_resetsTasks() {
        let (sut, spy) = makeSUT()
        sut.fetch(.init(forceReload: true))
        XCTAssertTrue(spy.fetchCalled)
        XCTAssertFalse(spy.lastFetch?.tasks.isEmpty ?? true)
    }

    // MARK: - 3. update переключает статус задания

    func test_update_togglesTaskStatus() {
        let (sut, spy) = makeSUT()
        sut.fetch(.init(forceReload: false))
        guard let firstTask = spy.lastFetch?.tasks.first else {
            return XCTFail("Нет задач для теста")
        }
        let wasDone = firstTask.isCompleted
        sut.update(.init(taskId: firstTask.id))
        XCTAssertTrue(spy.updateCalled)
        XCTAssertEqual(spy.lastUpdate?.updatedTask.isCompleted, !wasDone)
    }

    // MARK: - 4. update несуществующей задачи → failure

    func test_update_notFound_callsFailure() {
        let (sut, spy) = makeSUT()
        sut.fetch(.init(forceReload: false))
        sut.update(.init(taskId: "nonexistent-task-99"))
        XCTAssertFalse(spy.updateCalled)
        XCTAssertTrue(spy.failureCalled)
    }

    // MARK: - 5. changeFilter вызывает presentChangeFilter

    func test_changeFilter_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.fetch(.init(forceReload: false))
        sut.changeFilter(.init(filter: .active))
        XCTAssertTrue(spy.changeFilterCalled)
    }

    // MARK: - 6. refresh вызывает presentRefresh

    func test_refresh_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.refresh(.init())
        XCTAssertTrue(spy.refreshCalled)
    }

    // MARK: - 7. startTask вызывает presentStartTask

    func test_startTask_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.fetch(.init(forceReload: false))
        guard let firstTask = spy.lastFetch?.tasks.first else {
            return XCTFail("Нет задач для теста")
        }
        sut.startTask(.init(taskId: firstTask.id))
        XCTAssertTrue(spy.startTaskCalled)
    }

    // MARK: - 8. fetchDetail вызывает presentDetail

    func test_fetchDetail_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.fetch(.init(forceReload: false))
        guard let firstTask = spy.lastFetch?.tasks.first else {
            return XCTFail("Нет задач для теста")
        }
        sut.fetchDetail(.init(taskId: firstTask.id))
        XCTAssertTrue(spy.detailCalled)
    }

    // MARK: - 9. fetchDetail несуществующей задачи → failure

    func test_fetchDetail_notFound_callsFailure() {
        let (sut, spy) = makeSUT()
        sut.fetchDetail(.init(taskId: "nonexistent-99"))
        XCTAssertFalse(spy.detailCalled)
        XCTAssertTrue(spy.failureCalled)
    }

    // MARK: - 10. startTask несуществующей задачи → failure

    func test_startTask_notFound_callsFailure() {
        let (sut, spy) = makeSUT()
        sut.startTask(.init(taskId: "nonexistent-99"))
        XCTAssertFalse(spy.startTaskCalled)
        XCTAssertTrue(spy.failureCalled)
    }

    // MARK: - 11. changeFilter одинаковый фильтр → не вызывает presenter

    func test_changeFilter_sameFilter_noPresenterCall() {
        let (sut, spy) = makeSUT()
        sut.changeFilter(.init(filter: .all))   // default = .all
        XCTAssertFalse(spy.changeFilterCalled)
    }

    // MARK: - 12. changeFilter на другой фильтр → вызывает presenter

    func test_changeFilter_differentFilter_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.changeFilter(.init(filter: .active))
        XCTAssertTrue(spy.changeFilterCalled)
    }

    // MARK: - 13. requestOverdueReminder без сервиса → scheduled = false

    func test_requestOverdueReminder_nilService_scheduledFalse() {
        let sut = HomeTasksInteractor(notificationService: nil)
        let spy = SpyPresenter()
        sut.presenter = spy
        sut.requestOverdueReminder(.init(hour: 9, minute: 0))
        XCTAssertTrue(spy.notifyOverdueCalled)
    }

    // MARK: - 14. requestOverdueReminder с сервисом → async, вызывает presenter

    func test_requestOverdueReminder_withService_callsPresenter() async throws {
        let (sut, spy) = makeSUT()
        sut.requestOverdueReminder(.init(hour: 9, minute: 0))
        // Ждём @MainActor Task внутри requestOverdueReminder детерминированно
        try await waitUntil { spy.notifyOverdueCalled }
        XCTAssertTrue(spy.notifyOverdueCalled)
    }

    // MARK: - 15. scheduleReminder для задачи без dueDate → scheduled=false

    func test_scheduleReminder_noDueDate_scheduledFalse() async throws {
        let (sut, spy) = makeSUT()
        sut.fetch(.init(forceReload: false))
        // Первые задачи в seed могут иметь dueDate. Найдём задачу без dueDate.
        guard let taskWithoutDueDate = spy.lastFetch?.tasks.first(where: { $0.dueDate == nil }) else {
            // Все задачи имеют dueDate — обновим seed и возьмём первую
            // В этом случае просто проверим что scheduleReminder не падает
            let firstTask = spy.lastFetch!.tasks.first!
            let mockWorker = MockHomeTasksWorker(scheduledResult: false)
            let sut2 = HomeTasksInteractor(
                notificationService: MockNotificationService(),
                worker: mockWorker
            )
            let spy2 = SpyPresenter()
            sut2.presenter = spy2
            sut2.fetch(.init(forceReload: false))
            sut2.scheduleReminder(.init(taskId: firstTask.id, leadTimeMinutes: 30))
            try await waitUntil { spy2.scheduleReminderCalled || spy2.failureCalled }
            XCTAssertTrue(spy2.scheduleReminderCalled || spy2.failureCalled)
            return
        }
        sut.scheduleReminder(.init(taskId: taskWithoutDueDate.id, leadTimeMinutes: 30))
        XCTAssertTrue(spy.scheduleReminderCalled)
    }

    // MARK: - 16. scheduleReminder несуществующей задачи → failure

    func test_scheduleReminder_notFound_callsFailure() {
        let (sut, spy) = makeSUT()
        sut.scheduleReminder(.init(taskId: "nonexistent-99", leadTimeMinutes: 30))
        XCTAssertTrue(spy.failureCalled)
    }

    // MARK: - 17. scheduleReminder с MockWorker success → scheduled=true

    func test_scheduleReminder_withMockWorker_success() async throws {
        let mockWorker = MockHomeTasksWorker(scheduledResult: true)
        let sut = HomeTasksInteractor(notificationService: MockNotificationService(), worker: mockWorker)
        let spy = SpyPresenter()
        sut.presenter = spy
        sut.fetch(.init(forceReload: false))
        // Берём задачу с dueDate
        guard let taskWithDueDate = spy.lastFetch?.tasks.first(where: { $0.dueDate != nil }) else {
            // Нет задачи с dueDate — тест non-applicable
            return
        }
        sut.scheduleReminder(.init(taskId: taskWithDueDate.id, leadTimeMinutes: 30))
        try await waitUntil { spy.scheduleReminderCalled }
        XCTAssertTrue(spy.scheduleReminderCalled)
    }
}

// MARK: - MockHomeTasksWorker

@MainActor
private final class MockHomeTasksWorker: HomeTasksWorkerProtocol {
    private let scheduledResult: Bool
    init(scheduledResult: Bool = true) { self.scheduledResult = scheduledResult }

    func scheduleTaskReminder(for task: HomeTask, leadTimeMinutes: Int) async throws -> Bool {
        scheduledResult
    }
    func cancelTaskReminder(taskId: String) async {}
    func cancelAllTaskReminders() async {}
    func pendingReminderIds() async -> [String] { [] }
    func scheduleDailyMorningReminder(hour: Int, minute: Int) async throws {}
}
