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
}
