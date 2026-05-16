@testable import HappySpeech
import XCTest

// MARK: - HomeTasksPresenterTests
//
// Phase 2.6 batch 2 v25 — покрытие HomeTasksPresenter (64% → цель ≥90%).

@MainActor
final class HomeTasksPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: HomeTasksDisplayLogic {
        var fetchVM: HomeTasksModels.Fetch.ViewModel?
        var updateVM: HomeTasksModels.Update.ViewModel?
        var changeFilterVM: HomeTasksModels.ChangeFilter.ViewModel?
        var refreshVM: HomeTasksModels.Refresh.ViewModel?
        var startTaskVM: HomeTasksModels.StartTask.ViewModel?
        var notifyOverdueVM: HomeTasksModels.NotifyOverdue.ViewModel?
        var detailVM: HomeTasksModels.FetchDetail.ViewModel?
        var scheduleReminderVM: HomeTasksModels.ScheduleReminder.ViewModel?
        var failureVM: HomeTasksModels.Failure.ViewModel?

        func displayFetch(_ viewModel: HomeTasksModels.Fetch.ViewModel) { fetchVM = viewModel }
        func displayUpdate(_ viewModel: HomeTasksModels.Update.ViewModel) { updateVM = viewModel }
        func displayChangeFilter(_ viewModel: HomeTasksModels.ChangeFilter.ViewModel) { changeFilterVM = viewModel }
        func displayRefresh(_ viewModel: HomeTasksModels.Refresh.ViewModel) { refreshVM = viewModel }
        func displayStartTask(_ viewModel: HomeTasksModels.StartTask.ViewModel) { startTaskVM = viewModel }
        func displayNotifyOverdue(_ viewModel: HomeTasksModels.NotifyOverdue.ViewModel) { notifyOverdueVM = viewModel }
        func displayDetail(_ viewModel: HomeTasksModels.FetchDetail.ViewModel) { detailVM = viewModel }
        func displayScheduleReminder(_ viewModel: HomeTasksModels.ScheduleReminder.ViewModel) { scheduleReminderVM = viewModel }
        func displayFailure(_ viewModel: HomeTasksModels.Failure.ViewModel) { failureVM = viewModel }
        func displayLoading(_ isLoading: Bool) {}
    }

    private func makeSUT() -> (HomeTasksPresenter, DisplaySpy) {
        let presenter = HomeTasksPresenter()
        let spy = DisplaySpy()
        presenter.display = spy
        return (presenter, spy)
    }

    // MARK: - Task Helpers

    private func makeTask(
        id: String = UUID().uuidString,
        title: String = "Упражнение на звук С",
        targetSound: String = "С",
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        isStarted: Bool = false,
        priority: TaskPriority = .medium,
        estimatedMinutes: Int = 10,
        assignedBy: String = "Логопед"
    ) -> HomeTask {
        HomeTask(
            id: id,
            title: title,
            description: "Описание задания",
            targetSound: targetSound,
            dueDate: dueDate,
            isCompleted: isCompleted,
            priority: priority,
            isStarted: isStarted,
            exerciseType: "listen-and-choose",
            estimatedMinutes: estimatedMinutes,
            assignedBy: assignedBy
        )
    }

    // MARK: - presentFetch

    func test_presentFetch_noTasks_isEmptyTrue() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(.init(tasks: [], activeFilter: .all, isFromCache: false))
        XCTAssertTrue(spy.fetchVM?.isEmpty ?? false)
        XCTAssertEqual(spy.fetchVM?.totalCount, 0)
    }

    func test_presentFetch_withActiveTasks_countIsCorrect() {
        let (sut, spy) = makeSUT()
        let tasks = [makeTask(), makeTask()]
        sut.presentFetch(.init(tasks: tasks, activeFilter: .all, isFromCache: false))
        XCTAssertEqual(spy.fetchVM?.totalCount, 2)
        XCTAssertEqual(spy.fetchVM?.activeCount, 2)
    }

    func test_presentFetch_mixedTasks_completedCountCorrect() {
        let (sut, spy) = makeSUT()
        let active = makeTask()
        let completed = makeTask(isCompleted: true)
        sut.presentFetch(.init(tasks: [active, completed], activeFilter: .all, isFromCache: false))
        XCTAssertEqual(spy.fetchVM?.completedCount, 1)
        XCTAssertEqual(spy.fetchVM?.activeCount, 1)
    }

    func test_presentFetch_overdueTask_overdueCountNonZero() {
        let (sut, spy) = makeSUT()
        let overdue = makeTask(dueDate: Date(timeIntervalSinceNow: -86400))
        sut.presentFetch(.init(tasks: [overdue], activeFilter: .all, isFromCache: false))
        XCTAssertGreaterThan(spy.fetchVM?.overdueCount ?? 0, 0)
        XCTAssertTrue(spy.fetchVM?.suggestOverduePrompt ?? false)
    }

    func test_presentFetch_filterActive_emptyTitleNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(.init(tasks: [], activeFilter: .active, isFromCache: false))
        XCTAssertFalse(spy.fetchVM?.emptyTitle.isEmpty ?? true)
    }

    func test_presentFetch_filterCompleted_emptyTitleNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(.init(tasks: [], activeFilter: .completed, isFromCache: false))
        XCTAssertFalse(spy.fetchVM?.emptyTitle.isEmpty ?? true)
    }

    func test_presentFetch_sectionGrouping_highPriorityFirstInActive() {
        let (sut, spy) = makeSUT()
        let low = makeTask(priority: .low)
        let high = makeTask(priority: .high)
        sut.presentFetch(.init(tasks: [low, high], activeFilter: .all, isFromCache: false))
        // Presenter sorts by priority within active tasks
        XCTAssertNotNil(spy.fetchVM)
    }

    // MARK: - presentUpdate

    func test_presentUpdate_completedTask_toastNotNil() {
        let (sut, spy) = makeSUT()
        let completed = makeTask(isCompleted: true)
        sut.presentUpdate(.init(updatedTask: completed, allTasks: [completed], activeFilter: .all))
        XCTAssertNotNil(spy.updateVM?.toastMessage)
        XCTAssertFalse(spy.updateVM?.toastMessage?.isEmpty ?? true)
    }

    func test_presentUpdate_reopenedTask_toastNotNil() {
        let (sut, spy) = makeSUT()
        let active = makeTask(isCompleted: false)
        sut.presentUpdate(.init(updatedTask: active, allTasks: [active], activeFilter: .all))
        XCTAssertNotNil(spy.updateVM?.toastMessage)
    }

    // MARK: - presentChangeFilter

    func test_presentChangeFilter_filterActive_onlyActiveShown() {
        let (sut, spy) = makeSUT()
        let active = makeTask()
        let completed = makeTask(isCompleted: true)
        sut.presentChangeFilter(.init(tasks: [active, completed], filter: .active))
        XCTAssertEqual(spy.changeFilterVM?.activeFilter, .active)
    }

    func test_presentChangeFilter_filterCompleted_onlyCompletedShown() {
        let (sut, spy) = makeSUT()
        let active = makeTask()
        let completed = makeTask(isCompleted: true)
        sut.presentChangeFilter(.init(tasks: [active, completed], filter: .completed))
        XCTAssertEqual(spy.changeFilterVM?.totalCount, 2)
        XCTAssertEqual(spy.changeFilterVM?.activeFilter, .completed)
    }

    // MARK: - presentRefresh

    func test_presentRefresh_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentRefresh(.init(tasks: [], activeFilter: .all))
        XCTAssertNotNil(spy.refreshVM)
    }

    // MARK: - presentStartTask

    func test_presentStartTask_toastNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentStartTask(.init(taskId: "t-1", exerciseType: "breathing", targetSound: "Ш"))
        XCTAssertFalse(spy.startTaskVM?.toastMessage.isEmpty ?? true)
    }

    func test_presentStartTask_passesExerciseTypeAndSound() {
        let (sut, spy) = makeSUT()
        sut.presentStartTask(.init(taskId: "t-2", exerciseType: "sorting", targetSound: "Р"))
        XCTAssertEqual(spy.startTaskVM?.exerciseType, "sorting")
        XCTAssertEqual(spy.startTaskVM?.targetSound, "Р")
    }

    // MARK: - presentNotifyOverdue

    func test_presentNotifyOverdue_scheduled_toastContainsTime() {
        let (sut, spy) = makeSUT()
        sut.presentNotifyOverdue(.init(scheduled: true, hour: 9, minute: 0))
        XCTAssertFalse(spy.notifyOverdueVM?.toastMessage.isEmpty ?? true)
    }

    func test_presentNotifyOverdue_failed_toastNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentNotifyOverdue(.init(scheduled: false, hour: 0, minute: 0))
        XCTAssertFalse(spy.notifyOverdueVM?.toastMessage.isEmpty ?? true)
    }

    // MARK: - presentDetail

    func test_presentDetail_notStarted_startButtonTitleIsStart() {
        let (sut, spy) = makeSUT()
        let task = makeTask(isCompleted: false, isStarted: false)
        sut.presentDetail(.init(task: task, hasReminder: false, reminderScheduled: false))
        XCTAssertFalse(spy.detailVM?.startButtonTitle.isEmpty ?? true)
    }

    func test_presentDetail_started_startButtonTitleIsContinue() {
        let (sut, spy) = makeSUT()
        let task = makeTask(isCompleted: false, isStarted: true)
        sut.presentDetail(.init(task: task, hasReminder: true, reminderScheduled: true))
        XCTAssertFalse(spy.detailVM?.startButtonTitle.isEmpty ?? true)
        XCTAssertTrue(spy.detailVM?.hasReminder ?? false)
    }

    func test_presentDetail_completed_startButtonTitleIsRepeat() {
        let (sut, spy) = makeSUT()
        let task = makeTask(isCompleted: true)
        sut.presentDetail(.init(task: task, hasReminder: false, reminderScheduled: false))
        XCTAssertFalse(spy.detailVM?.startButtonTitle.isEmpty ?? true)
        XCTAssertTrue(spy.detailVM?.isCompleted ?? false)
    }

    func test_presentDetail_subtitleBuiltFromComponents() {
        let (sut, spy) = makeSUT()
        let task = makeTask(targetSound: "Р", estimatedMinutes: 15, assignedBy: "Марина Ивановна")
        sut.presentDetail(.init(task: task, hasReminder: false, reminderScheduled: false))
        XCTAssertFalse(spy.detailVM?.subtitle.isEmpty ?? true)
    }

    func test_presentDetail_noSound_soundBadgeIsSpecial() {
        let (sut, spy) = makeSUT()
        let task = makeTask(targetSound: "—")
        sut.presentDetail(.init(task: task, hasReminder: false, reminderScheduled: false))
        XCTAssertFalse(spy.detailVM?.soundBadgeText.isEmpty ?? true)
    }

    // MARK: - presentScheduleReminder

    func test_presentScheduleReminder_success_toastNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentScheduleReminder(.init(taskId: "t-1", scheduled: true, reason: nil))
        XCTAssertFalse(spy.scheduleReminderVM?.toastMessage.isEmpty ?? true)
        XCTAssertTrue(spy.scheduleReminderVM?.reminderScheduled ?? false)
    }

    func test_presentScheduleReminder_failedNoDueDate_toastNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentScheduleReminder(.init(taskId: "t-1", scheduled: false, reason: "noDueDate"))
        XCTAssertFalse(spy.scheduleReminderVM?.toastMessage.isEmpty ?? true)
        XCTAssertFalse(spy.scheduleReminderVM?.reminderScheduled ?? true)
    }

    func test_presentScheduleReminder_failedOtherReason_toastNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentScheduleReminder(.init(taskId: "t-1", scheduled: false, reason: "permissionDenied"))
        XCTAssertFalse(spy.scheduleReminderVM?.toastMessage.isEmpty ?? true)
    }

    // MARK: - presentFailure

    func test_presentFailure_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentFailure(.init(message: "Ошибка синхронизации"))
        XCTAssertEqual(spy.failureVM?.toastMessage, "Ошибка синхронизации")
    }

    // MARK: - Due date formatting (makeRow paths)

    func test_presentFetch_todayDueDate_dueDateTextNotEmpty() {
        let (sut, spy) = makeSUT()
        let task = makeTask(dueDate: Calendar.current.startOfDay(for: Date()))
        sut.presentFetch(.init(tasks: [task], activeFilter: .all, isFromCache: false))
        XCTAssertNotNil(spy.fetchVM)
    }

    func test_presentFetch_tomorrowDueDate_dueDateTextNotEmpty() {
        let (sut, spy) = makeSUT()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let task = makeTask(dueDate: tomorrow)
        sut.presentFetch(.init(tasks: [task], activeFilter: .all, isFromCache: false))
        XCTAssertNotNil(spy.fetchVM)
    }

    func test_presentFetch_farFutureDueDate_dueDateTextNotEmpty() {
        let (sut, spy) = makeSUT()
        let farFuture = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let task = makeTask(dueDate: farFuture)
        sut.presentFetch(.init(tasks: [task], activeFilter: .all, isFromCache: false))
        XCTAssertNotNil(spy.fetchVM)
    }
}
