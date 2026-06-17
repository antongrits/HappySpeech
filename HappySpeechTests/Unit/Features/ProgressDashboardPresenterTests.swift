@testable import HappySpeech
import XCTest

// MARK: - ProgressDashboardPresenterTests
//
// Verifies the non-trivial Response → ViewModel mapping in the parent-facing
// analytics presenter:
//   - summary cards: count, accuracy percent formatting, accent kinds
//   - soundCells sorted worst-accuracy-first, trend icon mapping, family hue
//   - topPerformers filter (>= 0.80) + top-3 cap + descending sort
//   - needsWork filter (< 0.60) + top-3 cap + ascending sort
//   - period options: selected flag matches request period
//   - recommendations: index ids preserved
//   - sound detail: percent + history mapping
//   - LLM summary: fallback flag passthrough
//   - insights: tone raw-value mapping
//   - empty state when no sounds
//   - failure toast

@MainActor
final class ProgressDashboardPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: ProgressDashboardDisplayLogic {
        var dashboardVM: ProgressDashboardModels.LoadDashboard.ViewModel?
        var detailVM: ProgressDashboardModels.LoadSoundDetail.ViewModel?
        var llmVM: ProgressDashboardModels.RequestLLMSummary.ViewModel?
        var insightsVM: ProgressDashboardModels.LoadInsights.ViewModel?
        var failureVM: ProgressDashboardModels.Failure.ViewModel?
        var insightsLoading: Bool?
        var llmLoading: Bool?
        var loading: Bool?

        func displayLoadDashboard(_ viewModel: ProgressDashboardModels.LoadDashboard.ViewModel) {
            dashboardVM = viewModel
        }
        func displayLoadSoundDetail(_ viewModel: ProgressDashboardModels.LoadSoundDetail.ViewModel) {
            detailVM = viewModel
        }
        func displayRequestLLMSummary(_ viewModel: ProgressDashboardModels.RequestLLMSummary.ViewModel) {
            llmVM = viewModel
        }
        func displayLoadInsights(_ viewModel: ProgressDashboardModels.LoadInsights.ViewModel) {
            insightsVM = viewModel
        }
        func displayInsightsLoading(_ isLoading: Bool) { insightsLoading = isLoading }
        func displayFailure(_ viewModel: ProgressDashboardModels.Failure.ViewModel) {
            failureVM = viewModel
        }
        func displayLoading(_ isLoading: Bool) { loading = isLoading }
        func displayLLMLoading(_ isLoading: Bool) { llmLoading = isLoading }
    }

    private func makeSUT() -> (ProgressDashboardPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = ProgressDashboardPresenter()
        presenter.display = spy
        return (presenter, spy)
    }

    private func summary(
        accuracy: Float = 0.75, streak: Int = 5, minutes: Int = 40, stars: Int = 12
    ) -> DashboardSummary {
        DashboardSummary(
            overallAccuracy: accuracy, streakDays: streak,
            totalMinutes: minutes, totalStars: stars
        )
    }

    private func sound(_ s: String, _ acc: Float, _ sessions: Int = 4,
                       _ trend: ProgressTrend = .stable) -> SoundProgress {
        SoundProgress(sound: s, accuracy: acc, sessions: sessions, trend: trend)
    }

    private func dashboardResponse(
        childName: String = "Маша",
        sounds: [SoundProgress],
        recommendations: [String] = [],
        period: ProgressDashboardModels.TimePeriod = .week
    ) -> ProgressDashboardModels.LoadDashboard.Response {
        ProgressDashboardModels.LoadDashboard.Response(
            childName: childName,
            summary: summary(),
            dailyAccuracy: [DailyAccuracy(day: "Пн", accuracy: 0.6),
                            DailyAccuracy(day: "Вт", accuracy: 0.7)],
            weeklyAccuracy: [WeeklyAccuracy(weekIndex: 0, label: "Нед 1", accuracy: 0.65)],
            sounds: sounds,
            recommendations: recommendations,
            period: period
        )
    }

    // MARK: - ChildName passthrough

    func test_loadDashboard_childNamePassedToViewModel() {
        let (sut, spy) = makeSUT()
        sut.presentLoadDashboard(dashboardResponse(childName: "Артём", sounds: [sound("С", 0.7)]))
        XCTAssertEqual(spy.dashboardVM?.childName, "Артём")
    }

    // MARK: - Summary cards

    func test_loadDashboard_producesFourSummaryCards() {
        let (sut, spy) = makeSUT()
        sut.presentLoadDashboard(dashboardResponse(sounds: [sound("С", 0.7)]))
        XCTAssertEqual(spy.dashboardVM?.summaryCards.count, 4)
    }

    func test_loadDashboard_accuracyCardFormatsPercent() {
        let (sut, spy) = makeSUT()
        var resp = dashboardResponse(sounds: [sound("С", 0.7)])
        resp = ProgressDashboardModels.LoadDashboard.Response(
            childName: resp.childName,
            summary: summary(accuracy: 0.83),
            dailyAccuracy: resp.dailyAccuracy,
            weeklyAccuracy: resp.weeklyAccuracy,
            sounds: resp.sounds, recommendations: [], period: .week
        )
        sut.presentLoadDashboard(resp)
        let card = spy.dashboardVM?.summaryCards.first { $0.kind == .accuracy }
        XCTAssertEqual(card?.value, "83%")
    }

    func test_loadDashboard_summaryCardKindsCoverAllFour() {
        let (sut, spy) = makeSUT()
        sut.presentLoadDashboard(dashboardResponse(sounds: [sound("С", 0.7)]))
        let kinds = Set((spy.dashboardVM?.summaryCards ?? []).map(\.kind))
        XCTAssertEqual(kinds, [.accuracy, .streak, .minutes, .stars])
    }

    // MARK: - Sound cells ordering & mapping

    func test_soundCells_sortedWorstFirst() {
        let (sut, spy) = makeSUT()
        let sounds = [sound("А", 0.90), sound("Б", 0.30), sound("В", 0.60)]
        sut.presentLoadDashboard(dashboardResponse(sounds: sounds))
        let order = (spy.dashboardVM?.soundCells ?? []).map(\.sound)
        XCTAssertEqual(order, ["Б", "В", "А"])
    }

    func test_soundCell_percentTextRounded() {
        let (sut, spy) = makeSUT()
        sut.presentLoadDashboard(dashboardResponse(sounds: [sound("С", 0.756)]))
        XCTAssertEqual(spy.dashboardVM?.soundCells.first?.accuracyText, "75%")
    }

    func test_soundCell_trendIconMapping() {
        let (sut, spy) = makeSUT()
        let sounds = [sound("У", 0.5, 4, .up), sound("Д", 0.4, 4, .down), sound("С", 0.3, 4, .stable)]
        sut.presentLoadDashboard(dashboardResponse(sounds: sounds))
        let cells = spy.dashboardVM?.soundCells ?? []
        let up = cells.first { $0.sound == "У" }
        let down = cells.first { $0.sound == "Д" }
        let stable = cells.first { $0.sound == "С" }
        XCTAssertEqual(up?.trendIconName, "arrow.up.right")
        XCTAssertEqual(down?.trendIconName, "arrow.down.right")
        XCTAssertEqual(stable?.trendIconName, "equal")
    }

    func test_soundCell_familyHueMapping() {
        let (sut, spy) = makeSUT()
        let sounds = [sound("С", 0.5), sound("Ш", 0.5), sound("Р", 0.5), sound("К", 0.5), sound("А", 0.5)]
        sut.presentLoadDashboard(dashboardResponse(sounds: sounds))
        let cells = spy.dashboardVM?.soundCells ?? []
        XCTAssertEqual(cells.first { $0.sound == "С" }?.familyHueName, "SoundWhistlingHue")
        XCTAssertEqual(cells.first { $0.sound == "Ш" }?.familyHueName, "SoundHissingHue")
        XCTAssertEqual(cells.first { $0.sound == "Р" }?.familyHueName, "SoundSonorantHue")
        XCTAssertEqual(cells.first { $0.sound == "К" }?.familyHueName, "SoundVelarHue")
        XCTAssertEqual(cells.first { $0.sound == "А" }?.familyHueName, "SoundVowelsHue")
    }

    // MARK: - Top performers (>= 0.80, top 3 desc)

    func test_topPerformers_filtersBelowThreshold() {
        let (sut, spy) = makeSUT()
        let sounds = [sound("А", 0.85), sound("Б", 0.50), sound("В", 0.79)]
        sut.presentLoadDashboard(dashboardResponse(sounds: sounds))
        let top = (spy.dashboardVM?.topPerformers ?? []).map(\.sound)
        XCTAssertEqual(top, ["А"])
    }

    func test_topPerformers_cappedAtThreeAndDescending() {
        let (sut, spy) = makeSUT()
        let sounds = [sound("А", 0.81), sound("Б", 0.99), sound("В", 0.90), sound("Г", 0.85)]
        sut.presentLoadDashboard(dashboardResponse(sounds: sounds))
        let top = (spy.dashboardVM?.topPerformers ?? []).map(\.sound)
        XCTAssertEqual(top, ["Б", "В", "Г"])
        XCTAssertTrue((spy.dashboardVM?.topPerformers ?? []).allSatisfy { $0.tone == .positive })
    }

    func test_topPerformers_boundaryAt80_included() {
        let (sut, spy) = makeSUT()
        sut.presentLoadDashboard(dashboardResponse(sounds: [sound("А", 0.80)]))
        XCTAssertEqual(spy.dashboardVM?.topPerformers.count, 1)
    }

    // MARK: - Needs work (< 0.60, top 3 asc)

    func test_needsWork_filtersAboveThreshold() {
        let (sut, spy) = makeSUT()
        let sounds = [sound("А", 0.59), sound("Б", 0.60), sound("В", 0.90)]
        sut.presentLoadDashboard(dashboardResponse(sounds: sounds))
        let work = (spy.dashboardVM?.needsWork ?? []).map(\.sound)
        XCTAssertEqual(work, ["А"])
    }

    func test_needsWork_ascendingAndCappedAtThree() {
        let (sut, spy) = makeSUT()
        let sounds = [sound("А", 0.55), sound("Б", 0.10), sound("В", 0.30), sound("Г", 0.45)]
        sut.presentLoadDashboard(dashboardResponse(sounds: sounds))
        let work = (spy.dashboardVM?.needsWork ?? []).map(\.sound)
        XCTAssertEqual(work, ["Б", "В", "Г"])
        XCTAssertTrue((spy.dashboardVM?.needsWork ?? []).allSatisfy { $0.tone == .attention })
    }

    // MARK: - Period options

    func test_periodOptions_coversAllCases() {
        let (sut, spy) = makeSUT()
        sut.presentLoadDashboard(dashboardResponse(sounds: [sound("С", 0.7)], period: .month))
        XCTAssertEqual(spy.dashboardVM?.periodOptions.count,
                       ProgressDashboardModels.TimePeriod.allCases.count)
    }

    func test_periodOptions_selectedFlagMatchesRequest() {
        let (sut, spy) = makeSUT()
        sut.presentLoadDashboard(dashboardResponse(sounds: [sound("С", 0.7)], period: .quarter))
        let selected = (spy.dashboardVM?.periodOptions ?? []).filter(\.isSelected)
        XCTAssertEqual(selected.count, 1)
        XCTAssertEqual(selected.first?.period, .quarter)
    }

    // MARK: - Recommendations

    func test_recommendations_preserveIndexIds() {
        let (sut, spy) = makeSUT()
        sut.presentLoadDashboard(dashboardResponse(
            sounds: [sound("С", 0.7)],
            recommendations: ["Совет 1", "Совет 2", "Совет 3"]
        ))
        let recs = spy.dashboardVM?.recommendations ?? []
        XCTAssertEqual(recs.map(\.id), [0, 1, 2])
        XCTAssertEqual(recs.map(\.text), ["Совет 1", "Совет 2", "Совет 3"])
    }

    // MARK: - Charts

    func test_dailyChart_scalesToPercent() {
        let (sut, spy) = makeSUT()
        sut.presentLoadDashboard(dashboardResponse(sounds: [sound("С", 0.7)]))
        // First daily accuracy 0.6 → 60.
        XCTAssertEqual(spy.dashboardVM?.dailyChart.first?.value ?? 0, 60, accuracy: 0.001)
    }

    func test_dailyAxisLabels_matchDays() {
        let (sut, spy) = makeSUT()
        sut.presentLoadDashboard(dashboardResponse(sounds: [sound("С", 0.7)]))
        XCTAssertEqual(spy.dashboardVM?.dailyAxisLabels, ["Пн", "Вт"])
    }

    // MARK: - Empty state

    func test_emptyState_whenNoSounds() {
        let (sut, spy) = makeSUT()
        sut.presentLoadDashboard(dashboardResponse(sounds: []))
        XCTAssertTrue(spy.dashboardVM?.isEmpty ?? false)
        XCTAssertEqual(spy.dashboardVM?.soundCells.count, 0)
    }

    func test_notEmpty_whenSoundsPresent() {
        let (sut, spy) = makeSUT()
        sut.presentLoadDashboard(dashboardResponse(sounds: [sound("С", 0.7)]))
        XCTAssertFalse(spy.dashboardVM?.isEmpty ?? true)
    }

    // MARK: - Sound detail

    func test_soundDetail_percentAndSessions() {
        let (sut, spy) = makeSUT()
        let response = ProgressDashboardModels.LoadSoundDetail.Response(
            progress: sound("Р", 0.642, 9, .up),
            history: [DailyAccuracy(day: "Пн", accuracy: 0.5)]
        )
        sut.presentLoadSoundDetail(response)
        XCTAssertEqual(spy.detailVM?.detail.accuracyPercent, 64)
        XCTAssertEqual(spy.detailVM?.detail.sessionsCount, 9)
        XCTAssertEqual(spy.detailVM?.detail.history.count, 1)
        XCTAssertEqual(spy.detailVM?.detail.trend, .up)
    }

    // MARK: - LLM summary

    func test_llmSummary_passesTextAndFallback() {
        let (sut, spy) = makeSUT()
        sut.presentRequestLLMSummary(.init(summaryText: "Хороший прогресс", isFallback: true))
        XCTAssertEqual(spy.llmVM?.summary.bodyText, "Хороший прогресс")
        XCTAssertEqual(spy.llmVM?.summary.isFallback, true)
    }

    // MARK: - Insights

    func test_insights_toneRawValueMapping() {
        let (sut, spy) = makeSUT()
        let insights = [
            ParentInsight(icon: "a", tone: .positive, text: "p"),
            ParentInsight(icon: "b", tone: .neutral, text: "n"),
            ParentInsight(icon: "c", tone: .warning, text: "w")
        ]
        sut.presentLoadInsights(.init(insights: insights))
        let cards = spy.insightsVM?.insightCards ?? []
        XCTAssertEqual(cards.map(\.toneRawValue), ["positive", "neutral", "warning"])
    }

    func test_insightsLoading_forwarded() {
        let (sut, spy) = makeSUT()
        sut.presentInsightsLoading(true)
        XCTAssertEqual(spy.insightsLoading, true)
    }

    func test_llmLoading_forwarded() {
        let (sut, spy) = makeSUT()
        sut.presentLLMLoading(true)
        XCTAssertEqual(spy.llmLoading, true)
    }

    // MARK: - Failure

    func test_failure_setsToastMessage() {
        let (sut, spy) = makeSUT()
        sut.presentFailure(.init(message: "Не удалось загрузить"))
        XCTAssertEqual(spy.failureVM?.toastMessage, "Не удалось загрузить")
    }
}
