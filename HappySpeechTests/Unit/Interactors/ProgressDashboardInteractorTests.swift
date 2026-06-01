@testable import HappySpeech
import XCTest

// MARK: - ProgressDashboardInteractorTests
//
// Покрывает РЕАЛЬНУЮ data-driven логику дашборда:
// loadDashboard (с данными / пустой ребёнок), changePeriod,
// loadSoundDetail (happy / not found), LLM fallback без сервиса.
// Данные приходят из мок-worker'а (агрегация реальных сессий замокана).

@MainActor
final class ProgressDashboardInteractorTests: XCTestCase {

    // MARK: - Spy Presenter

    @MainActor
    private final class SpyPresenter: ProgressDashboardPresentationLogic {
        var loadingCalls: [Bool] = []
        var loadDashboardCalled = false
        var loadSoundDetailCalled = false
        var llmSummaryCalled = false
        var llmLoadingCalled = false
        var failureCalled = false

        var lastLoadDashboardResponse: ProgressDashboardModels.LoadDashboard.Response?
        var lastSoundDetailResponse: ProgressDashboardModels.LoadSoundDetail.Response?
        var lastLLMResponse: ProgressDashboardModels.RequestLLMSummary.Response?
        var lastFailureResponse: ProgressDashboardModels.Failure.Response?

        var onLoadDashboard: (() -> Void)?

        func presentLoading(_ isLoading: Bool) { loadingCalls.append(isLoading) }
        func presentLoadDashboard(_ response: ProgressDashboardModels.LoadDashboard.Response) {
            loadDashboardCalled = true
            lastLoadDashboardResponse = response
            onLoadDashboard?()
        }
        func presentLoadSoundDetail(_ response: ProgressDashboardModels.LoadSoundDetail.Response) {
            loadSoundDetailCalled = true
            lastSoundDetailResponse = response
        }
        func presentRequestLLMSummary(_ response: ProgressDashboardModels.RequestLLMSummary.Response) {
            llmSummaryCalled = true
            lastLLMResponse = response
        }
        func presentLoadInsights(_ response: ProgressDashboardModels.LoadInsights.Response) {}
        func presentInsightsLoading(_ isLoading: Bool) {}
        func presentLLMLoading(_ isLoading: Bool) { llmLoadingCalled = true }
        func presentFailure(_ response: ProgressDashboardModels.Failure.Response) {
            failureCalled = true
            lastFailureResponse = response
        }
    }

    // MARK: - Stub Worker

    @MainActor
    private final class StubWorker: ProgressDashboardAggregating {
        var aggregate: DashboardAggregate
        init(aggregate: DashboardAggregate) { self.aggregate = aggregate }
        func aggregate(
            childId: String,
            period: ProgressDashboardModels.TimePeriod
        ) async -> DashboardAggregate {
            aggregate
        }
    }

    // MARK: - Fixtures

    private func nonEmptyAggregate() -> DashboardAggregate {
        let daily = [
            DailyAccuracy(day: "Пн", accuracy: 0.6),
            DailyAccuracy(day: "Вт", accuracy: 0.8)
        ]
        let sounds = [
            SoundProgress(sound: "Р", accuracy: 0.74, sessions: 3, trend: .up),
            SoundProgress(sound: "С", accuracy: 0.45, sessions: 2, trend: .down)
        ]
        return DashboardAggregate(
            summary: DashboardSummary(overallAccuracy: 0.7, streakDays: 4, totalMinutes: 90, totalStars: 12),
            daily: daily,
            weekly: [WeeklyAccuracy(weekIndex: 1, label: "Нед 1", accuracy: 0.7)],
            sounds: sounds,
            soundHistory: ["Р": daily, "С": daily]
        )
    }

    private func makeSUT(aggregate: DashboardAggregate) -> (ProgressDashboardInteractor, SpyPresenter) {
        let sut = ProgressDashboardInteractor(worker: StubWorker(aggregate: aggregate), llmDecisionService: nil)
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    /// Дожидается асинхронного presentLoadDashboard.
    private func awaitLoad(_ sut: ProgressDashboardInteractor, _ spy: SpyPresenter, period: ProgressDashboardModels.TimePeriod, childId: String = "child-1") async {
        let exp = expectation(description: "loadDashboard")
        spy.onLoadDashboard = { exp.fulfill() }
        sut.loadDashboard(.init(childId: childId, forceReload: true, period: period))
        await fulfillment(of: [exp], timeout: 2.0)
    }

    // MARK: - 1. loadDashboard (week) с данными → presenter получает реальные sounds

    func test_loadDashboard_withData_presentsRealAggregate() async {
        let (sut, spy) = makeSUT(aggregate: nonEmptyAggregate())
        await awaitLoad(sut, spy, period: .week)
        XCTAssertTrue(spy.loadDashboardCalled)
        XCTAssertEqual(spy.lastLoadDashboardResponse?.sounds.count, 2)
        XCTAssertEqual(spy.lastLoadDashboardResponse?.summary.streakDays, 4)
        XCTAssertEqual(spy.lastLoadDashboardResponse?.summary.totalMinutes, 90)
    }

    // MARK: - 2. loadDashboard передаёт period в response

    func test_loadDashboard_month_periodPropagated() async {
        let (sut, spy) = makeSUT(aggregate: nonEmptyAggregate())
        await awaitLoad(sut, spy, period: .month)
        XCTAssertEqual(spy.lastLoadDashboardResponse?.period, .month)
    }

    // MARK: - 3. Пустой ребёнок (нет сессий) → empty aggregate, sounds пусты

    func test_loadDashboard_emptyChild_presentsEmpty() async {
        let (sut, spy) = makeSUT(aggregate: .empty)
        await awaitLoad(sut, spy, period: .week)
        XCTAssertTrue(spy.lastLoadDashboardResponse?.sounds.isEmpty ?? false)
        XCTAssertEqual(spy.lastLoadDashboardResponse?.summary.overallAccuracy, 0)
        XCTAssertEqual(spy.lastLoadDashboardResponse?.summary.totalStars, 0)
    }

    // MARK: - 4. Нет worker'а вовсе → graceful empty (не краш, не фейк)

    func test_loadDashboard_noWorker_presentsEmpty() async {
        let sut = ProgressDashboardInteractor(worker: nil, llmDecisionService: nil)
        let spy = SpyPresenter()
        sut.presenter = spy
        let exp = expectation(description: "load")
        spy.onLoadDashboard = { exp.fulfill() }
        sut.loadDashboard(.init(childId: "child-1", forceReload: true, period: .week))
        await fulfillment(of: [exp], timeout: 2.0)
        XCTAssertTrue(spy.lastLoadDashboardResponse?.sounds.isEmpty ?? false)
    }

    // MARK: - 5. loadDashboard выставляет loading=true перед загрузкой

    func test_loadDashboard_setsLoadingTrue() async {
        let (sut, spy) = makeSUT(aggregate: nonEmptyAggregate())
        await awaitLoad(sut, spy, period: .week)
        XCTAssertEqual(spy.loadingCalls.first, true)
    }

    // MARK: - 6. changePeriod делегирует к loadDashboard

    func test_changePeriod_quarter_callsLoadDashboard() async {
        let (sut, spy) = makeSUT(aggregate: nonEmptyAggregate())
        let exp = expectation(description: "change")
        spy.onLoadDashboard = { exp.fulfill() }
        sut.changePeriod(.init(childId: "child-1", period: .quarter))
        await fulfillment(of: [exp], timeout: 2.0)
        XCTAssertTrue(spy.loadDashboardCalled)
        XCTAssertEqual(spy.lastLoadDashboardResponse?.period, .quarter)
    }

    // MARK: - 7. loadSoundDetail (существующий звук из реальных данных) → presenter

    func test_loadSoundDetail_existingSound_callsPresenter() async {
        let (sut, spy) = makeSUT(aggregate: nonEmptyAggregate())
        await awaitLoad(sut, spy, period: .week)
        sut.loadSoundDetail(.init(sound: "Р"))
        XCTAssertTrue(spy.loadSoundDetailCalled)
        XCTAssertNotNil(spy.lastSoundDetailResponse)
    }

    // MARK: - 8. loadSoundDetail (несуществующий звук) → presentFailure

    func test_loadSoundDetail_notFound_callsFailure() async {
        let (sut, spy) = makeSUT(aggregate: nonEmptyAggregate())
        await awaitLoad(sut, spy, period: .week)
        sut.loadSoundDetail(.init(sound: "ЗЗЗ_НЕСУЩЕСТВУЮЩИЙ"))
        XCTAssertFalse(spy.loadSoundDetailCalled)
        XCTAssertTrue(spy.failureCalled)
    }

    // MARK: - 9. requestLLMSummary без сервиса → isFallback = true

    func test_requestLLMSummary_withoutService_usesFallback() {
        let (sut, _) = makeSUT(aggregate: nonEmptyAggregate())
        let spy = SpyPresenter()
        sut.presenter = spy
        let summary = DashboardSummary(overallAccuracy: 0.75, streakDays: 3, totalMinutes: 60, totalStars: 10)
        sut.requestLLMSummary(.init(childName: "Маша", summary: summary, topSound: nil))
        XCTAssertTrue(spy.llmSummaryCalled)
        XCTAssertEqual(spy.lastLLMResponse?.isFallback, true)
        XCTAssertFalse(spy.lastLLMResponse?.summaryText.isEmpty ?? true)
    }
}
