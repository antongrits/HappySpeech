@testable import HappySpeech
import XCTest

// MARK: - Stub Workers

@MainActor
private final class StubInsightAggregator: InsightAggregatorWorkerProtocol {
    var weekInsights: [DailyInsight] = []
    var stubbedSummary = WeeklySummary(
        totalSessions: 0, totalMinutes: 0, averageSuccessRate: 0,
        activeDays: 0, bestDayId: nil
    )
    private(set) var buildWeekCallCount = 0

    func buildWeek(childId: String, endingOn date: Date) async -> [DailyInsight] {
        buildWeekCallCount += 1
        return weekInsights
    }
    func summary(from insights: [DailyInsight]) -> WeeklySummary {
        stubbedSummary
    }
}

@MainActor
private final class StubLLMInsightWorker: LLMInsightWorkerProtocol {
    var enrichResult: ([DailyInsight], Bool) = ([], false)
    var passthrough = true
    private(set) var enrichCallCount = 0

    func enrich(insights: [DailyInsight], childName: String) async -> ([DailyInsight], Bool) {
        enrichCallCount += 1
        if passthrough { return (insights, enrichResult.1) }
        return enrichResult
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyParentInsightsTimelinePresenter: ParentInsightsTimelinePresentationLogic, @unchecked Sendable {
    var loadCallCount = 0
    var selectDayCallCount = 0
    var refreshCallCount = 0

    var lastLoad: ParentInsightsTimelineModels.Load.Response?
    var lastSelectDay: ParentInsightsTimelineModels.SelectDay.Response?
    var lastRefresh: ParentInsightsTimelineModels.Refresh.Response?

    func presentLoad(response: ParentInsightsTimelineModels.Load.Response) async {
        loadCallCount += 1
        lastLoad = response
    }
    func presentSelectDay(response: ParentInsightsTimelineModels.SelectDay.Response) async {
        selectDayCallCount += 1
        lastSelectDay = response
    }
    func presentRefresh(response: ParentInsightsTimelineModels.Refresh.Response) async {
        refreshCallCount += 1
        lastRefresh = response
    }
}

// MARK: - Tests

@MainActor
final class ParentInsightsTimelineInteractorTests: XCTestCase {

    private func insight(
        id: String = "2026-05-13",
        sessions: Int = 2,
        minutes: Int = 8,
        rate: Double = 0.9,
        llm: String? = nil,
        isToday: Bool = false
    ) -> DailyInsight {
        DailyInsight(
            id: id,
            day: Date(),
            weekdayShort: "Пн",
            sessionCount: sessions,
            minutesPracticed: minutes,
            successRate: rate,
            severity: .positive,
            llmComment: llm,
            isToday: isToday
        )
    }

    private func makeSUT(
        children: [ChildProfileDTO] = [TestDataBuilder.childProfile(id: "c1", name: "Маша")]
    ) -> (
        ParentInsightsTimelineInteractor,
        SpyParentInsightsTimelinePresenter,
        StubInsightAggregator,
        StubLLMInsightWorker,
        SpyChildRepository
    ) {
        let aggregator = StubInsightAggregator()
        let llm = StubLLMInsightWorker()
        let childRepo = SpyChildRepository(children: children)
        let sut = ParentInsightsTimelineInteractor(
            aggregator: aggregator,
            llmWorker: llm,
            childRepository: childRepo
        )
        let spy = SpyParentInsightsTimelinePresenter()
        sut.presenter = spy
        return (sut, spy, aggregator, llm, childRepo)
    }

    // MARK: - load

    func test_load_emitsResponseWithChildName() async {
        let (sut, spy, _, _, _) = makeSUT()
        await sut.load(request: .init(childId: "c1", weekEndingOn: Date()))
        XCTAssertEqual(spy.loadCallCount, 1)
        XCTAssertEqual(spy.lastLoad?.childName, "Маша")
    }

    func test_load_unknownChild_usesDashName() async {
        let (sut, spy, _, _, _) = makeSUT(children: [])
        await sut.load(request: .init(childId: "missing", weekEndingOn: Date()))
        XCTAssertEqual(spy.lastLoad?.childName, "—")
    }

    func test_load_storesInsights() async {
        let (sut, spy, aggregator, _, _) = makeSUT()
        aggregator.weekInsights = [insight(id: "d1"), insight(id: "d2")]
        await sut.load(request: .init(childId: "c1", weekEndingOn: Date()))
        XCTAssertEqual(sut.currentInsights.count, 2)
        XCTAssertEqual(spy.lastLoad?.insights.count, 2)
    }

    func test_load_callsAggregatorAndLLM() async {
        let (sut, _, aggregator, llm, _) = makeSUT()
        await sut.load(request: .init(childId: "c1", weekEndingOn: Date()))
        XCTAssertEqual(aggregator.buildWeekCallCount, 1)
        XCTAssertEqual(llm.enrichCallCount, 1)
    }

    func test_load_usedLLMFlagPropagated() async {
        let (sut, spy, _, llm, _) = makeSUT()
        llm.enrichResult = ([], true)
        await sut.load(request: .init(childId: "c1", weekEndingOn: Date()))
        XCTAssertTrue(spy.lastLoad?.usedLLM ?? false)
    }

    func test_load_storesChildName() async {
        let (sut, _, _, _, _) = makeSUT()
        await sut.load(request: .init(childId: "c1", weekEndingOn: Date()))
        XCTAssertEqual(sut.currentChildName, "Маша")
    }

    // MARK: - selectDay

    func test_selectDay_unknownId_ignored() async {
        let (sut, spy, _, _, _) = makeSUT()
        await sut.load(request: .init(childId: "c1", weekEndingOn: Date()))
        await sut.selectDay(request: .init(dayId: "nonexistent"))
        XCTAssertEqual(spy.selectDayCallCount, 0)
    }

    func test_selectDay_withLLMComment_usesIt() async {
        let (sut, spy, aggregator, _, _) = makeSUT()
        aggregator.weekInsights = [insight(id: "d1", llm: "Отличная неделя!")]
        await sut.load(request: .init(childId: "c1", weekEndingOn: Date()))
        await sut.selectDay(request: .init(dayId: "d1"))
        XCTAssertEqual(spy.selectDayCallCount, 1)
        XCTAssertEqual(spy.lastSelectDay?.detail, "Отличная неделя!")
    }

    func test_selectDay_withoutLLMComment_usesHeuristic() async {
        let (sut, spy, aggregator, _, _) = makeSUT()
        aggregator.weekInsights = [insight(id: "d1", llm: nil)]
        await sut.load(request: .init(childId: "c1", weekEndingOn: Date()))
        await sut.selectDay(request: .init(dayId: "d1"))
        XCTAssertEqual(spy.selectDayCallCount, 1)
        XCTAssertFalse(spy.lastSelectDay?.detail.isEmpty ?? true)
    }

    func test_selectDay_emptyLLMComment_fallsBackToHeuristic() async {
        let (sut, spy, aggregator, _, _) = makeSUT()
        aggregator.weekInsights = [insight(id: "d1", llm: "")]
        await sut.load(request: .init(childId: "c1", weekEndingOn: Date()))
        await sut.selectDay(request: .init(dayId: "d1"))
        XCTAssertFalse(spy.lastSelectDay?.detail.isEmpty ?? true)
    }

    func test_selectDay_returnsCorrectInsight() async {
        let (sut, spy, aggregator, _, _) = makeSUT()
        aggregator.weekInsights = [insight(id: "d1"), insight(id: "d2")]
        await sut.load(request: .init(childId: "c1", weekEndingOn: Date()))
        await sut.selectDay(request: .init(dayId: "d2"))
        XCTAssertEqual(spy.lastSelectDay?.insight.id, "d2")
    }

    // MARK: - refresh

    func test_refresh_reloadsAndEmitsRefreshResponse() async {
        let (sut, spy, aggregator, _, _) = makeSUT()
        await sut.refresh(request: .init(childId: "c1"))
        XCTAssertEqual(spy.loadCallCount, 1, "refresh вызывает load")
        XCTAssertEqual(spy.refreshCallCount, 1)
        XCTAssertTrue(spy.lastRefresh?.success ?? false)
        XCTAssertEqual(aggregator.buildWeekCallCount, 1)
    }

    func test_refresh_toastKeyNotEmpty() async {
        let (sut, spy, _, _, _) = makeSUT()
        await sut.refresh(request: .init(childId: "c1"))
        XCTAssertFalse(spy.lastRefresh?.toastKey.isEmpty ?? true)
    }

    // MARK: - WeekTimelineBuilder pure helpers

    func test_emptyWeek_returnsSevenDays() {
        let week = WeekTimelineBuilder.emptyWeek(endingOn: Date())
        XCTAssertEqual(week.count, 7)
        XCTAssertTrue(week.last?.isToday ?? false)
    }

    func test_severity_positiveWhenActiveAndHighRate() {
        XCTAssertEqual(
            WeekTimelineBuilder.severity(sessionCount: 3, successRate: 0.8, isToday: false),
            .positive
        )
    }

    func test_severity_attentionWhenEmptyPastDay() {
        XCTAssertEqual(
            WeekTimelineBuilder.severity(sessionCount: 0, successRate: 0, isToday: false),
            .attention
        )
    }

    func test_severity_neutralWhenEmptyToday() {
        XCTAssertEqual(
            WeekTimelineBuilder.severity(sessionCount: 0, successRate: 0, isToday: true),
            .neutral
        )
    }

    func test_heuristicComment_todayEmpty() {
        let comment = WeekTimelineBuilder.heuristicComment(
            sessionCount: 0, minutes: 0, successRate: 0, isToday: true
        )
        XCTAssertFalse(comment.isEmpty)
    }

    func test_heuristicComment_pastDayEmpty() {
        let comment = WeekTimelineBuilder.heuristicComment(
            sessionCount: 0, minutes: 0, successRate: 0, isToday: false
        )
        XCTAssertFalse(comment.isEmpty)
    }

    func test_heuristicComment_greatDay() {
        let comment = WeekTimelineBuilder.heuristicComment(
            sessionCount: 3, minutes: 12, successRate: 0.9, isToday: false
        )
        XCTAssertFalse(comment.isEmpty)
    }

    func test_heuristicComment_goodDay() {
        let comment = WeekTimelineBuilder.heuristicComment(
            sessionCount: 2, minutes: 8, successRate: 0.7, isToday: false
        )
        XCTAssertFalse(comment.isEmpty)
    }

    func test_heuristicComment_tryAgainDay() {
        let comment = WeekTimelineBuilder.heuristicComment(
            sessionCount: 1, minutes: 3, successRate: 0.4, isToday: false
        )
        XCTAssertFalse(comment.isEmpty)
    }

    func test_insightSeverity_symbolsNotEmpty() {
        for severity in InsightSeverity.allCases {
            XCTAssertFalse(severity.symbolName.isEmpty)
        }
    }
}
