@testable import HappySpeech
import XCTest

// MARK: - Spy DisplayLogic (chart adapter scope)

@MainActor
private final class SpyChartDisplay: PlainProgressDisplayLogic, @unchecked Sendable {
    var loadVM: PlainProgressModels.Load.ViewModel?
    var errorMessage: String?
    var shareVM: PlainProgressModels.Share.ViewModel?

    func displayLoad(viewModel: PlainProgressModels.Load.ViewModel) async { loadVM = viewModel }
    func displayLoadFailure(message: String) async { errorMessage = message }
    func displayShare(viewModel: PlainProgressModels.Share.ViewModel) async { shareVM = viewModel }
}

@MainActor
private func buildResponse(
    weekRate: Double,
    monthRate: Double,
    sessions: Int = 5
) -> PlainProgressModels.Load.Response {
    .init(
        childName: "Аня",
        childAge: 6,
        weekSuccessRate: weekRate,
        previousWeekSuccessRate: monthRate,
        monthAgoSuccessRate: monthRate,
        sessionsThisWeek: sessions,
        practiceMinutesThisWeek: 30,
        focusSound: "С",
        focusSoundRate: weekRate,
        targetSounds: ["С"],
        currentStreak: 3,
        trend: .improved,
        hasWeekData: true
    )
}

// MARK: - Chart adapter — Presenter contract tests
//
// v31 Волна C Ф.3 — Swift Charts rebuild. Контракт Presenter не меняется:
// `ComparisonViewModel` остаётся с теми же полями. Эти тесты фиксируют
// что adapter передаёт BarMark-ready данные в правильных диапазонах.

@MainActor
final class PlainProgressChartAdapterTests: XCTestCase {

    func test_comparison_fractions_areClampedTo0_1() async {
        let display = SpyChartDisplay()
        let presenter = PlainProgressPresenter(displayLogic: display)
        let response = buildResponse(weekRate: 0.85, monthRate: 0.42)
        await presenter.presentLoad(response: response)
        let comparison = display.loadVM?.comparison
        XCTAssertNotNil(comparison)
        XCTAssertGreaterThanOrEqual(comparison?.monthAgoFraction ?? -1, 0)
        XCTAssertLessThanOrEqual(comparison?.monthAgoFraction ?? 2, 1)
        XCTAssertGreaterThanOrEqual(comparison?.nowFraction ?? -1, 0)
        XCTAssertLessThanOrEqual(comparison?.nowFraction ?? 2, 1)
    }

    func test_comparison_nowGreaterMonth_whenWeekHigher() async {
        let display = SpyChartDisplay()
        let presenter = PlainProgressPresenter(displayLogic: display)
        await presenter.presentLoad(response: buildResponse(weekRate: 0.9, monthRate: 0.3))
        let comparison = display.loadVM?.comparison
        XCTAssertGreaterThan(
            (comparison?.nowFraction ?? 0),
            (comparison?.monthAgoFraction ?? 1)
        )
    }

    func test_comparison_labelsArePresent() async {
        let display = SpyChartDisplay()
        let presenter = PlainProgressPresenter(displayLogic: display)
        await presenter.presentLoad(response: buildResponse(weekRate: 0.5, monthRate: 0.5))
        let comparison = display.loadVM?.comparison
        XCTAssertNotNil(comparison)
        XCTAssertFalse(comparison?.title.isEmpty ?? true)
        XCTAssertFalse(comparison?.monthAgoLabel.isEmpty ?? true)
        XCTAssertFalse(comparison?.nowLabel.isEmpty ?? true)
        XCTAssertFalse(comparison?.deltaText.isEmpty ?? true)
    }

    func test_comparison_valueStrings_containPercent() async {
        let display = SpyChartDisplay()
        let presenter = PlainProgressPresenter(displayLogic: display)
        await presenter.presentLoad(response: buildResponse(weekRate: 0.75, monthRate: 0.50))
        let comparison = display.loadVM?.comparison
        XCTAssertTrue((comparison?.nowValue ?? "").contains("%"))
        XCTAssertTrue((comparison?.monthAgoValue ?? "").contains("%"))
    }

    func test_comparison_nilWhenInsufficientData() async {
        let display = SpyChartDisplay()
        let presenter = PlainProgressPresenter(displayLogic: display)
        let response = PlainProgressModels.Load.Response(
            childName: "Аня",
            childAge: 6,
            weekSuccessRate: 0,
            previousWeekSuccessRate: 0,
            monthAgoSuccessRate: 0,
            sessionsThisWeek: 0,
            practiceMinutesThisWeek: 0,
            focusSound: "С",
            focusSoundRate: 0,
            targetSounds: ["С"],
            currentStreak: 0,
            trend: .noData,
            hasWeekData: false
        )
        await presenter.presentLoad(response: response)
        XCTAssertNil(display.loadVM?.comparison)
    }
}
