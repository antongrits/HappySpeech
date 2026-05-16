@testable import HappySpeech
import XCTest

// MARK: - ReportsPresenterTests
//
// Phase 2.6 batch 2 v25 — покрытие ReportsPresenter (62% → цель ≥90%).

@MainActor
final class ReportsPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: ReportsDisplayLogic {
        var fetchReportVM: ReportsModels.FetchReport.ViewModel?
        var exportReportVM: ReportsModels.ExportReport.ViewModel?

        func displayFetchReport(_ viewModel: ReportsModels.FetchReport.ViewModel) { fetchReportVM = viewModel }
        func displayExportReport(_ viewModel: ReportsModels.ExportReport.ViewModel) { exportReportVM = viewModel }
    }

    private func makeSUT() -> (ReportsPresenter, DisplaySpy) {
        let presenter = ReportsPresenter()
        let spy = DisplaySpy()
        presenter.display = spy
        return (presenter, spy)
    }

    private func makeSummary(
        totalSessions: Int = 10,
        totalMinutes: Int = 100,
        overallSuccessRate: Double = 0.75
    ) -> ReportSummary {
        ReportSummary(
            totalSessions: totalSessions,
            totalMinutes: totalMinutes,
            overallSuccessRate: overallSuccessRate,
            improvedSounds: ["С"],
            strugglingSounds: []
        )
    }

    // MARK: - presentFetchReport

    func test_presentFetchReport_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentFetchReport(.init(summary: makeSummary(), soundBreakdown: [], sessionTimeline: []))
        XCTAssertNotNil(spy.fetchReportVM)
    }

    func test_presentFetchReport_titleNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentFetchReport(.init(summary: makeSummary(), soundBreakdown: [], sessionTimeline: []))
        XCTAssertFalse(spy.fetchReportVM?.titleText.isEmpty ?? true)
    }

    func test_presentFetchReport_rangeLabelNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentFetchReport(.init(summary: makeSummary(), soundBreakdown: [], sessionTimeline: []))
        XCTAssertFalse(spy.fetchReportVM?.rangeLabel.isEmpty ?? true)
    }

    func test_presentFetchReport_overallSuccessPercentCalculated() async {
        let (sut, spy) = makeSUT()
        await sut.presentFetchReport(.init(summary: makeSummary(overallSuccessRate: 0.82), soundBreakdown: [], sessionTimeline: []))
        XCTAssertEqual(spy.fetchReportVM?.overallSuccessPercent, 82)
    }

    func test_presentFetchReport_soundBreakdownPassedThrough() async {
        let (sut, spy) = makeSUT()
        let row = SoundBreakdownRow(sound: "С", attempts: 10, successes: 8, averageConfidence: 0.8, currentStageTitle: "Слоги", weekOverWeekDelta: 0.05)
        await sut.presentFetchReport(.init(summary: makeSummary(), soundBreakdown: [row], sessionTimeline: []))
        XCTAssertEqual(spy.fetchReportVM?.rows.count, 1)
    }

    func test_presentFetchReport_timelinePassedThrough() async {
        let (sut, spy) = makeSUT()
        let entry = SessionTimelineEntry(date: Date(), durationMinutes: 15, activityCount: 3, averageScore: 0.7)
        await sut.presentFetchReport(.init(summary: makeSummary(), soundBreakdown: [], sessionTimeline: [entry]))
        XCTAssertEqual(spy.fetchReportVM?.timeline.count, 1)
    }

    func test_presentFetchReport_zeroSuccessRate_returnsZeroPercent() async {
        let (sut, spy) = makeSUT()
        await sut.presentFetchReport(.init(summary: makeSummary(overallSuccessRate: 0.0), soundBreakdown: [], sessionTimeline: []))
        XCTAssertEqual(spy.fetchReportVM?.overallSuccessPercent, 0)
    }

    func test_presentFetchReport_totalSessionsTextNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentFetchReport(.init(summary: makeSummary(totalSessions: 5), soundBreakdown: [], sessionTimeline: []))
        XCTAssertFalse(spy.fetchReportVM?.totalSessionsText.isEmpty ?? true)
    }

    func test_presentFetchReport_totalMinutesTextNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentFetchReport(.init(summary: makeSummary(totalMinutes: 60), soundBreakdown: [], sessionTimeline: []))
        XCTAssertFalse(spy.fetchReportVM?.totalMinutesText.isEmpty ?? true)
    }

    // MARK: - presentExportReport

    func test_presentExportReport_callsDisplay() async {
        let (sut, spy) = makeSUT()
        let url = URL(fileURLWithPath: "/tmp/report.pdf")
        await sut.presentExportReport(.init(fileURL: url, bytes: 512))
        XCTAssertNotNil(spy.exportReportVM)
    }

    func test_presentExportReport_shareableURLPassedThrough() async {
        let (sut, spy) = makeSUT()
        let url = URL(fileURLWithPath: "/tmp/report.pdf")
        await sut.presentExportReport(.init(fileURL: url, bytes: 512))
        XCTAssertEqual(spy.exportReportVM?.shareableURL, url)
    }

    func test_presentExportReport_smallFile_sizeTextUsesBytes() async {
        let (sut, spy) = makeSUT()
        let url = URL(fileURLWithPath: "/tmp/report.pdf")
        // bytes < 1024 → format bytes (mb = 512/1024 = 0.5 < 1)
        await sut.presentExportReport(.init(fileURL: url, bytes: 512))
        XCTAssertFalse(spy.exportReportVM?.sizeText.isEmpty ?? true)
    }

    func test_presentExportReport_largeFile_sizeTextUsesKB() async {
        let (sut, spy) = makeSUT()
        let url = URL(fileURLWithPath: "/tmp/report.csv")
        // bytes = 2048 → mb = 2048/1024 = 2.0 >= 1 → KB format
        await sut.presentExportReport(.init(fileURL: url, bytes: 2048))
        XCTAssertTrue(spy.exportReportVM?.sizeText.contains("KB") ?? false)
    }

    func test_presentExportReport_exactlyOneKB_usesKBFormat() async {
        let (sut, spy) = makeSUT()
        let url = URL(fileURLWithPath: "/tmp/report.csv")
        // bytes = 1024 → mb = 1.0 — boundary, uses KB format
        await sut.presentExportReport(.init(fileURL: url, bytes: 1024))
        XCTAssertTrue(spy.exportReportVM?.sizeText.contains("KB") ?? false)
    }
}
