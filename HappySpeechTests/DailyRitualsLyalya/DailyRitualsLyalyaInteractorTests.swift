@testable import HappySpeech
import XCTest

@MainActor
private final class StubDailyRitualsPresenter: DailyRitualsLyalyaPresentationLogic, @unchecked Sendable {
    var lastLoad: DailyRitualsLyalyaModels.Load.Response?
    var lastToggle: DailyRitualsLyalyaModels.ToggleReminder.Response?
    var lastUpdateTime: DailyRitualsLyalyaModels.UpdateTime.Response?
    var lastPermission: DailyRitualsLyalyaModels.RequestPermission.Response?
    var loadCount = 0

    func presentLoad(response: DailyRitualsLyalyaModels.Load.Response) async {
        lastLoad = response
        loadCount += 1
    }

    func presentToggleReminder(response: DailyRitualsLyalyaModels.ToggleReminder.Response) async {
        lastToggle = response
    }

    func presentUpdateTime(response: DailyRitualsLyalyaModels.UpdateTime.Response) async {
        lastUpdateTime = response
    }

    func presentPermissionResult(response: DailyRitualsLyalyaModels.RequestPermission.Response) async {
        lastPermission = response
    }
}

@MainActor
private final class MockDailyRitualsWorker: DailyRitualsLyalyaWorkerProtocol, @unchecked Sendable {
    var enabledMap: [RitualKind: Bool] = [:]
    var timeMap: [RitualKind: ReminderTime] = [:]
    var authorized: Bool = true
    var permissionGranted: Bool = true

    var scheduleCalled: [(RitualKind, ReminderTime)] = []
    var cancelCalled: [RitualKind] = []
    var requestAuthCount = 0

    func steps(for kind: RitualKind) -> [RitualStep] {
        DailyRitualsLyalyaCorpus.steps(for: kind)
    }

    func reminderEnabled(for kind: RitualKind) -> Bool {
        enabledMap[kind] ?? false
    }

    func reminderTime(for kind: RitualKind) -> ReminderTime {
        timeMap[kind] ?? ReminderTime(hour: kind.defaultHour, minute: kind.defaultMinute)
    }

    func setReminderEnabled(_ enabled: Bool, for kind: RitualKind) {
        enabledMap[kind] = enabled
    }

    func setReminderTime(_ time: ReminderTime, for kind: RitualKind) {
        timeMap[kind] = time
    }

    func notificationAuthorizationStatus() async -> Bool {
        authorized
    }

    func requestNotificationAuthorization() async -> Bool {
        requestAuthCount += 1
        if permissionGranted {
            authorized = true
        }
        return permissionGranted
    }

    func scheduleReminder(for kind: RitualKind, time: ReminderTime) async {
        scheduleCalled.append((kind, time))
    }

    func cancelReminder(for kind: RitualKind) async {
        cancelCalled.append(kind)
    }
}

@MainActor
final class DailyRitualsLyalyaInteractorTests: XCTestCase {

    private func makeSUT() -> (DailyRitualsLyalyaInteractor, StubDailyRitualsPresenter, MockDailyRitualsWorker) {
        let worker = MockDailyRitualsWorker()
        let sut = DailyRitualsLyalyaInteractor(worker: worker)
        let presenter = StubDailyRitualsPresenter()
        sut.presenter = presenter
        return (sut, presenter, worker)
    }

    func test_load_buildsResponseWithSteps() async {
        let (sut, presenter, _) = makeSUT()
        await sut.load(request: .init(kind: .morning))
        XCTAssertEqual(presenter.lastLoad?.kind, .morning)
        XCTAssertEqual(presenter.lastLoad?.steps.count, DailyRitualsLyalyaCorpus.morningSteps.count)
    }

    func test_load_usesDefaultsTime() async {
        let (sut, presenter, _) = makeSUT()
        await sut.load(request: .init(kind: .morning))
        XCTAssertEqual(presenter.lastLoad?.reminderTime.hour, RitualKind.morning.defaultHour)
        XCTAssertEqual(presenter.lastLoad?.reminderTime.minute, RitualKind.morning.defaultMinute)
    }

    func test_toggleReminder_enable_schedulesAndPersists() async {
        let (sut, _, worker) = makeSUT()
        worker.authorized = true
        await sut.toggleReminder(request: .init(kind: .morning, isEnabled: true))
        XCTAssertEqual(worker.scheduleCalled.count, 1)
        XCTAssertEqual(worker.scheduleCalled.first?.0, .morning)
        XCTAssertEqual(worker.enabledMap[.morning], true)
    }

    func test_toggleReminder_disable_cancels() async {
        let (sut, _, worker) = makeSUT()
        worker.enabledMap[.morning] = true
        await sut.toggleReminder(request: .init(kind: .morning, isEnabled: false))
        XCTAssertEqual(worker.cancelCalled.contains(.morning), true)
        XCTAssertEqual(worker.enabledMap[.morning], false)
    }

    func test_toggleReminder_enableWithoutAuthorization_signalsAuthorizationNeeded() async {
        let (sut, presenter, worker) = makeSUT()
        worker.authorized = false
        await sut.toggleReminder(request: .init(kind: .morning, isEnabled: true))
        XCTAssertEqual(presenter.lastToggle?.authorizationNeeded, true)
        XCTAssertEqual(presenter.lastToggle?.isEnabled, false)
        XCTAssertEqual(worker.scheduleCalled.count, 0)
    }

    func test_updateTime_persistsAndReschedulesWhenEnabled() async {
        let (sut, _, worker) = makeSUT()
        worker.enabledMap[.morning] = true
        worker.authorized = true
        let newTime = ReminderTime(hour: 9, minute: 15)
        await sut.updateTime(request: .init(kind: .morning, time: newTime))
        XCTAssertEqual(worker.timeMap[.morning], newTime)
        XCTAssertTrue(worker.scheduleCalled.contains { $0.1 == newTime })
    }

    func test_updateTime_persistsButDoesNotScheduleWhenDisabled() async {
        let (sut, _, worker) = makeSUT()
        worker.enabledMap[.morning] = false
        let newTime = ReminderTime(hour: 9, minute: 15)
        await sut.updateTime(request: .init(kind: .morning, time: newTime))
        XCTAssertEqual(worker.timeMap[.morning], newTime)
        XCTAssertFalse(worker.scheduleCalled.contains { $0.1 == newTime })
    }

    func test_requestPermission_granted_autoEnablesReminder() async {
        let (sut, _, worker) = makeSUT()
        worker.permissionGranted = true
        worker.authorized = false
        await sut.requestPermission(request: .init(kind: .morning))
        XCTAssertEqual(worker.requestAuthCount, 1)
    }
}
