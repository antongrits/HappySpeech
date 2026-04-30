@testable import HappySpeech
import XCTest

// MARK: - ProgressDashboardInteractorTests
//
// M10.1 — 6 тестов для ProgressDashboardInteractor.
// Покрывает: loadDashboard (week/month), changePeriod,
// loadSoundDetail (happy/not found), LLM fallback без сервиса.

@MainActor
final class ProgressDashboardInteractorTests: XCTestCase {

    // MARK: - Spy

    @MainActor
    private final class SpyPresenter: ProgressDashboardPresentationLogic {
        var loadDashboardCalled = false
        var loadSoundDetailCalled = false
        var llmSummaryCalled = false
        var llmLoadingCalled = false
        var failureCalled = false

        var lastLoadDashboardResponse: ProgressDashboardModels.LoadDashboard.Response?
        var lastSoundDetailResponse: ProgressDashboardModels.LoadSoundDetail.Response?
        var lastLLMResponse: ProgressDashboardModels.RequestLLMSummary.Response?
        var lastFailureResponse: ProgressDashboardModels.Failure.Response?

        func presentLoadDashboard(_ response: ProgressDashboardModels.LoadDashboard.Response) {
            loadDashboardCalled = true
            lastLoadDashboardResponse = response
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
        func presentLLMLoading(_ isLoading: Bool) {
            llmLoadingCalled = true
        }
        func presentFailure(_ response: ProgressDashboardModels.Failure.Response) {
            failureCalled = true
            lastFailureResponse = response
        }
    }

    private func makeSUT() -> (ProgressDashboardInteractor, SpyPresenter) {
        let sut = ProgressDashboardInteractor(llmDecisionService: nil)
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. loadDashboard (week) вызывает presentLoadDashboard

    func test_loadDashboard_week_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadDashboard(.init(childId: "child-1", forceReload: false, period: .week))
        XCTAssertTrue(spy.loadDashboardCalled)
        XCTAssertNotNil(spy.lastLoadDashboardResponse)
    }

    // MARK: - 2. loadDashboard (month) передаёт period в response

    func test_loadDashboard_month_periodPropagated() {
        let (sut, spy) = makeSUT()
        sut.loadDashboard(.init(childId: "child-1", forceReload: false, period: .month))
        XCTAssertEqual(spy.lastLoadDashboardResponse?.period, .month)
    }

    // MARK: - 3. changePeriod делегирует к loadDashboard

    func test_changePeriod_quarter_callsLoadDashboard() {
        let (sut, spy) = makeSUT()
        sut.changePeriod(.init(childId: "child-1", period: .quarter))
        XCTAssertTrue(spy.loadDashboardCalled)
        XCTAssertEqual(spy.lastLoadDashboardResponse?.period, .quarter)
    }

    // MARK: - 4. loadSoundDetail (существующий звук) → presentLoadSoundDetail

    func test_loadSoundDetail_existingSound_callsPresenter() {
        let (sut, spy) = makeSUT()
        // Сначала загружаем дашборд чтобы заполнить внутренние sounds.
        sut.loadDashboard(.init(childId: "child-1", forceReload: false, period: .week))
        // Звук "Р" присутствует в seed данных.
        sut.loadSoundDetail(.init(sound: "Р"))
        XCTAssertTrue(spy.loadSoundDetailCalled)
        XCTAssertNotNil(spy.lastSoundDetailResponse)
    }

    // MARK: - 5. loadSoundDetail (несуществующий звук) → presentFailure

    func test_loadSoundDetail_notFound_callsFailure() {
        let (sut, spy) = makeSUT()
        sut.loadDashboard(.init(childId: "child-1", forceReload: false, period: .week))
        sut.loadSoundDetail(.init(sound: "ЗЗЗ_НЕСУЩЕСТВУЮЩИЙ"))
        XCTAssertFalse(spy.loadSoundDetailCalled)
        XCTAssertTrue(spy.failureCalled)
    }

    // MARK: - 6. requestLLMSummary без сервиса → isFallback = true

    func test_requestLLMSummary_withoutService_usesFallback() {
        let (sut, spy) = makeSUT()
        let emptySummary = DashboardSummary(
            overallAccuracy: 0.75,
            streakDays: 3,
            totalMinutes: 60,
            totalStars: 10
        )
        sut.requestLLMSummary(.init(childName: "Маша", summary: emptySummary, topSound: nil))
        XCTAssertTrue(spy.llmSummaryCalled)
        XCTAssertEqual(spy.lastLLMResponse?.isFallback, true)
        XCTAssertFalse(spy.lastLLMResponse?.summaryText.isEmpty ?? true)
    }
}
