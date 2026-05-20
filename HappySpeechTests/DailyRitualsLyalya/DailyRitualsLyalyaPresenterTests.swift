@testable import HappySpeech
import XCTest

@MainActor
private final class SpyDailyRitualsDisplay: DailyRitualsLyalyaDisplayLogic, @unchecked Sendable {
    var loadVM: DailyRitualsLyalyaModels.Load.ViewModel?
    var toggleResponse: DailyRitualsLyalyaModels.ToggleReminder.Response?
    var updateResponse: DailyRitualsLyalyaModels.UpdateTime.Response?
    var permissionResponse: DailyRitualsLyalyaModels.RequestPermission.Response?

    func displayLoad(viewModel: DailyRitualsLyalyaModels.Load.ViewModel) async { loadVM = viewModel }
    func displayToggleReminder(response: DailyRitualsLyalyaModels.ToggleReminder.Response) async { toggleResponse = response }
    func displayUpdateTime(response: DailyRitualsLyalyaModels.UpdateTime.Response) async { updateResponse = response }
    func displayPermissionResult(response: DailyRitualsLyalyaModels.RequestPermission.Response) async { permissionResponse = response }
}

@MainActor
final class DailyRitualsLyalyaPresenterTests: XCTestCase {

    private func makeSUT() -> (DailyRitualsLyalyaPresenter, SpyDailyRitualsDisplay) {
        let spy = SpyDailyRitualsDisplay()
        let sut = DailyRitualsLyalyaPresenter(displayLogic: spy)
        return (sut, spy)
    }

    private func makeMorningResponse(
        reminderEnabled: Bool = false,
        authorized: Bool = true,
        hour: Int = 8,
        minute: Int = 0
    ) -> DailyRitualsLyalyaModels.Load.Response {
        .init(
            kind: .morning,
            steps: DailyRitualsLyalyaCorpus.morningSteps,
            reminderEnabled: reminderEnabled,
            reminderTime: ReminderTime(hour: hour, minute: minute),
            notificationsAuthorized: authorized
        )
    }

    func test_presentLoad_buildsStepsForKind() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: makeMorningResponse())
        XCTAssertEqual(spy.loadVM?.steps.count, DailyRitualsLyalyaCorpus.morningSteps.count)
    }

    func test_presentLoad_propagatesReminderEnabled() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: makeMorningResponse(reminderEnabled: true))
        XCTAssertEqual(spy.loadVM?.reminderEnabled, true)
    }

    func test_presentLoad_buildsReminderTimeLabel() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: makeMorningResponse(hour: 7, minute: 30))
        XCTAssertEqual(spy.loadVM?.reminderTimeLabel, "07:30")
    }

    func test_presentLoad_needsAuthorization_whenEnabledAndNotAuthorized() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: makeMorningResponse(reminderEnabled: true, authorized: false))
        XCTAssertEqual(spy.loadVM?.needsAuthorization, true)
    }

    func test_presentLoad_doesNotNeedAuthorization_whenDisabled() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: makeMorningResponse(reminderEnabled: false, authorized: false))
        XCTAssertEqual(spy.loadVM?.needsAuthorization, false)
    }

    func test_presentLoad_totalMinutesIsNonZero() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: makeMorningResponse())
        XCTAssertFalse(spy.loadVM?.totalMinutesLabel.isEmpty ?? true)
    }

    func test_presentLoad_eveningKindUsesEveningSteps() async {
        let (sut, spy) = makeSUT()
        let response = DailyRitualsLyalyaModels.Load.Response(
            kind: .evening,
            steps: DailyRitualsLyalyaCorpus.eveningSteps,
            reminderEnabled: false,
            reminderTime: ReminderTime(hour: 19, minute: 30),
            notificationsAuthorized: true
        )
        await sut.presentLoad(response: response)
        XCTAssertEqual(spy.loadVM?.kind, .evening)
        XCTAssertEqual(spy.loadVM?.steps.count, DailyRitualsLyalyaCorpus.eveningSteps.count)
    }

    func test_presentToggleReminder_forwards() async {
        let (sut, spy) = makeSUT()
        await sut.presentToggleReminder(
            response: .init(kind: .morning, isEnabled: true, authorizationNeeded: false)
        )
        XCTAssertEqual(spy.toggleResponse?.kind, .morning)
        XCTAssertEqual(spy.toggleResponse?.isEnabled, true)
    }
}
