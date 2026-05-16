@testable import HappySpeech
import XCTest

// MARK: - ParentInsightsTimelinePresenterTests
//
// Phase 2.6 batch 2 v25 — покрытие ParentInsightsTimelinePresenter (0% → цель ≥90%).

@MainActor
final class ParentInsightsTimelinePresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: ParentInsightsTimelineDisplayLogic {
        var loadVM: ParentInsightsTimelineModels.Load.ViewModel?
        var selectDayVM: ParentInsightsTimelineModels.SelectDay.ViewModel?
        var refreshVM: ParentInsightsTimelineModels.Refresh.ViewModel?

        func displayLoad(viewModel: ParentInsightsTimelineModels.Load.ViewModel) async { loadVM = viewModel }
        func displaySelectDay(viewModel: ParentInsightsTimelineModels.SelectDay.ViewModel) async { selectDayVM = viewModel }
        func displayRefresh(viewModel: ParentInsightsTimelineModels.Refresh.ViewModel) async { refreshVM = viewModel }
    }

    private func makeSUT() -> (ParentInsightsTimelinePresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = ParentInsightsTimelinePresenter(displayLogic: spy)
        return (presenter, spy)
    }

    private func makeDailyInsight(
        id: String = "2026-05-13",
        severity: InsightSeverity = .neutral,
        sessionCount: Int = 2,
        minutesPracticed: Int = 10,
        successRate: Double = 0.75,
        llmComment: String? = nil,
        isToday: Bool = false
    ) -> DailyInsight {
        DailyInsight(
            id: id,
            day: Date(),
            weekdayShort: "Вт",
            sessionCount: sessionCount,
            minutesPracticed: minutesPracticed,
            successRate: successRate,
            severity: severity,
            llmComment: llmComment,
            isToday: isToday
        )
    }

    private func makeWeeklySummary(
        totalSessions: Int = 7,
        totalMinutes: Int = 40,
        averageSuccessRate: Double = 0.7,
        activeDays: Int = 5
    ) -> WeeklySummary {
        WeeklySummary(
            totalSessions: totalSessions,
            totalMinutes: totalMinutes,
            averageSuccessRate: averageSuccessRate,
            activeDays: activeDays,
            bestDayId: nil
        )
    }

    // MARK: - presentLoad

    func test_presentLoad_callsDisplay() async {
        let (sut, spy) = makeSUT()
        let insights = [makeDailyInsight()]
        let response = ParentInsightsTimelineModels.Load.Response(
            insights: insights,
            summary: makeWeeklySummary(),
            childName: "Маша",
            usedLLM: false
        )
        await sut.presentLoad(response: response)
        XCTAssertNotNil(spy.loadVM)
    }

    func test_presentLoad_heroTitleNotEmpty() async {
        let (sut, spy) = makeSUT()
        let response = ParentInsightsTimelineModels.Load.Response(
            insights: [makeDailyInsight()],
            summary: makeWeeklySummary(),
            childName: "Маша",
            usedLLM: false
        )
        await sut.presentLoad(response: response)
        XCTAssertFalse(spy.loadVM?.heroTitle.isEmpty ?? true)
    }

    func test_presentLoad_emptyInsights_heroSubtitleEmpty() async {
        let (sut, spy) = makeSUT()
        let response = ParentInsightsTimelineModels.Load.Response(
            insights: [],
            summary: makeWeeklySummary(),
            childName: "Ваня",
            usedLLM: false
        )
        await sut.presentLoad(response: response)
        XCTAssertEqual(spy.loadVM?.heroSubtitle, "")
    }

    func test_presentLoad_withInsights_heroSubtitleNotEmpty() async {
        let (sut, spy) = makeSUT()
        let insights = [makeDailyInsight(id: "2026-05-10"), makeDailyInsight(id: "2026-05-16")]
        let response = ParentInsightsTimelineModels.Load.Response(
            insights: insights,
            summary: makeWeeklySummary(),
            childName: "Маша",
            usedLLM: false
        )
        await sut.presentLoad(response: response)
        XCTAssertFalse(spy.loadVM?.heroSubtitle.isEmpty ?? true)
    }

    func test_presentLoad_cellsBuiltFromInsights() async {
        let (sut, spy) = makeSUT()
        let insights = [makeDailyInsight(), makeDailyInsight(id: "2026-05-14")]
        let response = ParentInsightsTimelineModels.Load.Response(
            insights: insights,
            summary: makeWeeklySummary(),
            childName: "Маша",
            usedLLM: false
        )
        await sut.presentLoad(response: response)
        XCTAssertEqual(spy.loadVM?.cells.count, 2)
    }

    func test_presentLoad_llmComment_usedInCell() async {
        let (sut, spy) = makeSUT()
        let insight = makeDailyInsight(llmComment: "Отличная работа!")
        let response = ParentInsightsTimelineModels.Load.Response(
            insights: [insight],
            summary: makeWeeklySummary(),
            childName: "Маша",
            usedLLM: true
        )
        await sut.presentLoad(response: response)
        XCTAssertEqual(spy.loadVM?.cells.first?.comment, "Отличная работа!")
    }

    func test_presentLoad_noLlmComment_usesHeuristic() async {
        let (sut, spy) = makeSUT()
        let insight = makeDailyInsight(sessionCount: 0, llmComment: nil, isToday: false)
        let response = ParentInsightsTimelineModels.Load.Response(
            insights: [insight],
            summary: makeWeeklySummary(),
            childName: "Маша",
            usedLLM: false
        )
        await sut.presentLoad(response: response)
        XCTAssertFalse(spy.loadVM?.cells.first?.comment.isEmpty ?? true)
    }

    func test_presentLoad_summaryStatsCount() async {
        let (sut, spy) = makeSUT()
        let response = ParentInsightsTimelineModels.Load.Response(
            insights: [makeDailyInsight()],
            summary: makeWeeklySummary(),
            childName: "Маша",
            usedLLM: false
        )
        await sut.presentLoad(response: response)
        XCTAssertEqual(spy.loadVM?.summaryStats.count, 4)
    }

    func test_presentLoad_llmSourceLabelNotEmpty() async {
        let (sut, spy) = makeSUT()
        let response = ParentInsightsTimelineModels.Load.Response(
            insights: [makeDailyInsight()],
            summary: makeWeeklySummary(),
            childName: "Маша",
            usedLLM: true
        )
        await sut.presentLoad(response: response)
        XCTAssertFalse(spy.loadVM?.llmSourceLabel.isEmpty ?? true)
    }

    func test_presentLoad_attentionSeverity_symbolName() async {
        let (sut, spy) = makeSUT()
        let insight = makeDailyInsight(severity: .attention)
        let response = ParentInsightsTimelineModels.Load.Response(
            insights: [insight],
            summary: makeWeeklySummary(),
            childName: "Маша",
            usedLLM: false
        )
        await sut.presentLoad(response: response)
        XCTAssertEqual(spy.loadVM?.cells.first?.severitySymbol, "exclamationmark.triangle.fill")
    }

    func test_presentLoad_positiveSeverity_symbolName() async {
        let (sut, spy) = makeSUT()
        let insight = makeDailyInsight(severity: .positive)
        let response = ParentInsightsTimelineModels.Load.Response(
            insights: [insight],
            summary: makeWeeklySummary(),
            childName: "Маша",
            usedLLM: false
        )
        await sut.presentLoad(response: response)
        XCTAssertEqual(spy.loadVM?.cells.first?.severitySymbol, "checkmark.seal.fill")
    }

    func test_presentLoad_cellA11yLabelNotEmpty() async {
        let (sut, spy) = makeSUT()
        let response = ParentInsightsTimelineModels.Load.Response(
            insights: [makeDailyInsight()],
            summary: makeWeeklySummary(),
            childName: "Маша",
            usedLLM: false
        )
        await sut.presentLoad(response: response)
        XCTAssertFalse(spy.loadVM?.cells.first?.accessibilityLabel.isEmpty ?? true)
    }

    // MARK: - presentSelectDay

    func test_presentSelectDay_callsDisplay() async {
        let (sut, spy) = makeSUT()
        let insight = makeDailyInsight(severity: .positive)
        await sut.presentSelectDay(response: .init(insight: insight, detail: "Подробности"))
        XCTAssertNotNil(spy.selectDayVM)
    }

    func test_presentSelectDay_titleLabelNotEmpty() async {
        let (sut, spy) = makeSUT()
        let insight = makeDailyInsight(severity: .neutral)
        await sut.presentSelectDay(response: .init(insight: insight, detail: "Детали"))
        XCTAssertFalse(spy.selectDayVM?.titleLabel.isEmpty ?? true)
    }

    func test_presentSelectDay_metricsLabelNotEmpty() async {
        let (sut, spy) = makeSUT()
        let insight = makeDailyInsight(severity: .positive)
        await sut.presentSelectDay(response: .init(insight: insight, detail: "Текст"))
        XCTAssertFalse(spy.selectDayVM?.metricsLabel.isEmpty ?? true)
    }

    func test_presentSelectDay_detailParagraphPassedThrough() async {
        let (sut, spy) = makeSUT()
        let detail = "Подробное описание дня"
        await sut.presentSelectDay(response: .init(insight: makeDailyInsight(), detail: detail))
        XCTAssertEqual(spy.selectDayVM?.detailParagraph, detail)
    }

    func test_presentSelectDay_attentionSeverity_hasRecommendation() async {
        let (sut, spy) = makeSUT()
        let insight = makeDailyInsight(severity: .attention)
        await sut.presentSelectDay(response: .init(insight: insight, detail: ""))
        XCTAssertNotNil(spy.selectDayVM?.recommendationLabel)
    }

    func test_presentSelectDay_positiveSeverity_hasRecommendation() async {
        let (sut, spy) = makeSUT()
        let insight = makeDailyInsight(severity: .positive)
        await sut.presentSelectDay(response: .init(insight: insight, detail: ""))
        XCTAssertNotNil(spy.selectDayVM?.recommendationLabel)
    }

    func test_presentSelectDay_neutralSeverity_noRecommendation() async {
        let (sut, spy) = makeSUT()
        let insight = makeDailyInsight(severity: .neutral)
        await sut.presentSelectDay(response: .init(insight: insight, detail: ""))
        XCTAssertNil(spy.selectDayVM?.recommendationLabel)
    }

    // MARK: - presentRefresh

    func test_presentRefresh_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentRefresh(response: .init(success: true, toastKey: "parentInsightsTimeline.refresh.success"))
        XCTAssertNotNil(spy.refreshVM)
    }

    func test_presentRefresh_toastMessageNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentRefresh(response: .init(success: true, toastKey: "parentInsightsTimeline.refresh.success"))
        XCTAssertFalse(spy.refreshVM?.toastMessage.isEmpty ?? true)
    }
}
