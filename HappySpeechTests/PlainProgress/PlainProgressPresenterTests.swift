@testable import HappySpeech
import XCTest

// MARK: - Spy DisplayLogic

@MainActor
private final class SpyPlainProgressDisplay: PlainProgressDisplayLogic, @unchecked Sendable {
    var loadVM: PlainProgressModels.Load.ViewModel?
    var errorMessage: String?
    var shareVM: PlainProgressModels.Share.ViewModel?

    func displayLoad(viewModel: PlainProgressModels.Load.ViewModel) async {
        loadVM = viewModel
    }
    func displayLoadFailure(message: String) async {
        errorMessage = message
    }
    func displayShare(viewModel: PlainProgressModels.Share.ViewModel) async {
        shareVM = viewModel
    }
}

@MainActor
private func makeResponse(
    weekRate: Double,
    monthRate: Double,
    sessions: Int,
    hasData: Bool,
    trend: PlainProgressDirection,
    streak: Int = 3,
    focusRate: Double? = nil
) -> PlainProgressModels.Load.Response {
    .init(
        childName: "Аня",
        childAge: 6,
        weekSuccessRate: weekRate,
        previousWeekSuccessRate: 0.6,
        monthAgoSuccessRate: monthRate,
        sessionsThisWeek: sessions,
        practiceMinutesThisWeek: 30,
        focusSound: "С",
        focusSoundRate: focusRate ?? weekRate,
        targetSounds: ["С"],
        currentStreak: streak,
        trend: trend,
        hasWeekData: hasData
    )
}

// MARK: - Presenter Tests

@MainActor
final class PlainProgressPresenterTests: XCTestCase {

    private func makeSUT() -> (PlainProgressPresenter, SpyPlainProgressDisplay) {
        let display = SpyPlainProgressDisplay()
        let sut = PlainProgressPresenter(displayLogic: display)
        return (sut, display)
    }

    func test_presentLoad_buildsNarrativeAndMilestones() async {
        let (sut, display) = makeSUT()
        await sut.presentLoad(response: makeResponse(
            weekRate: 0.85, monthRate: 0.5, sessions: 5, hasData: true, trend: .improved
        ))
        XCTAssertNotNil(display.loadVM)
        XCTAssertFalse(display.loadVM?.narrative.body.isEmpty ?? true)
        XCTAssertEqual(display.loadVM?.milestones.count, 5)
    }

    func test_presentLoad_noData_setsEmptyStateText() async {
        let (sut, display) = makeSUT()
        await sut.presentLoad(response: makeResponse(
            weekRate: 0, monthRate: 0, sessions: 0, hasData: false, trend: .noData
        ))
        XCTAssertNotNil(display.loadVM?.emptyStateText)
        XCTAssertNil(display.loadVM?.comparison)
    }

    func test_presentLoad_withData_buildsComparison() async {
        let (sut, display) = makeSUT()
        await sut.presentLoad(response: makeResponse(
            weekRate: 0.8, monthRate: 0.5, sessions: 5, hasData: true, trend: .improved
        ))
        XCTAssertNotNil(display.loadVM?.comparison)
        XCTAssertEqual(display.loadVM?.comparison?.nowValue, "80%")
        XCTAssertEqual(display.loadVM?.comparison?.monthAgoValue, "50%")
    }

    func test_presentLoad_highStreak_marksWeekStreakMilestoneReached() async {
        let (sut, display) = makeSUT()
        await sut.presentLoad(response: makeResponse(
            weekRate: 0.8, monthRate: 0.5, sessions: 5, hasData: true,
            trend: .improved, streak: 8
        ))
        let weekStreak = display.loadVM?.milestones.first { $0.id == "milestone-week-streak" }
        XCTAssertEqual(weekStreak?.reached, true)
    }

    func test_presentLoad_lowStreak_weekStreakNotReached() async {
        let (sut, display) = makeSUT()
        await sut.presentLoad(response: makeResponse(
            weekRate: 0.8, monthRate: 0.5, sessions: 5, hasData: true,
            trend: .improved, streak: 2
        ))
        let weekStreak = display.loadVM?.milestones.first { $0.id == "milestone-week-streak" }
        XCTAssertEqual(weekStreak?.reached, false)
    }

    func test_presentLoadFailure_setsErrorMessage() async {
        let (sut, display) = makeSUT()
        await sut.presentLoadFailure(error: NSError(domain: "t", code: 1))
        XCTAssertNotNil(display.errorMessage)
    }

    func test_presentShare_buildsSummaryText() async {
        let (sut, display) = makeSUT()
        await sut.presentShare(response: makeResponse(
            weekRate: 0.8, monthRate: 0.5, sessions: 5, hasData: true, trend: .improved
        ))
        XCTAssertNotNil(display.shareVM)
        XCTAssertTrue(display.shareVM?.summaryText.contains("Аня") ?? false)
    }

    func test_presentLoad_improvedTrend_usesPositiveTint() async {
        let (sut, display) = makeSUT()
        await sut.presentLoad(response: makeResponse(
            weekRate: 0.9, monthRate: 0.5, sessions: 5, hasData: true, trend: .improved
        ))
        XCTAssertEqual(display.loadVM?.narrative.trendTint, .positive)
    }
}
