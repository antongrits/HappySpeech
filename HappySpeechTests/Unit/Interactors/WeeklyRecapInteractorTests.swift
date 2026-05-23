@testable import HappySpeech
import XCTest

// MARK: - WeeklyRecapInteractorTests
//
// WeeklyRecapInteractor is a thin VIP MVP variant (@Observable, no separate
// Presenter/DisplayLogic). Tests verify state and share output directly.

@MainActor
final class WeeklyRecapInteractorTests: XCTestCase {

    // MARK: - share()

    func test_share_returnsNonEmptyString() {
        let sut = WeeklyRecapInteractor()
        let text = sut.share()
        XCTAssertFalse(text.isEmpty)
    }

    func test_share_containsAllKPITitles() {
        let sut = WeeklyRecapInteractor()
        let text = sut.share()
        for kpi in sut.state.kpis {
            XCTAssertTrue(text.contains(kpi.title), "Expected share text to contain KPI title '\(kpi.title)'")
        }
    }

    func test_share_containsAllKPIValues() {
        let sut = WeeklyRecapInteractor()
        let text = sut.share()
        for kpi in sut.state.kpis {
            XCTAssertTrue(text.contains(kpi.value), "Expected share text to contain KPI value '\(kpi.value)'")
        }
    }

    func test_share_containsAllKPITrends() {
        let sut = WeeklyRecapInteractor()
        let text = sut.share()
        for kpi in sut.state.kpis {
            XCTAssertTrue(text.contains(kpi.trend), "Expected share text to contain KPI trend '\(kpi.trend)'")
        }
    }

    func test_share_withCustomState_reflectsCustomValues() {
        let sut = WeeklyRecapInteractor()
        sut.state = WeeklyRecapModels.ViewState(
            kpis: [
                .init(id: "min", title: "Минут", value: "99", trend: "+42", icon: "clock.fill")
            ],
            chartValues: [10, 20, 30]
        )
        let text = sut.share()
        XCTAssertTrue(text.contains("99"))
        XCTAssertTrue(text.contains("+42"))
    }

    // MARK: - state

    func test_defaultState_kpisHaveFourEntries() {
        let sut = WeeklyRecapInteractor()
        XCTAssertEqual(sut.state.kpis.count, 4)
    }

    func test_defaultState_chartValuesHaveSevenPoints() {
        let sut = WeeklyRecapInteractor()
        XCTAssertEqual(sut.state.chartValues.count, 7)
    }

    func test_defaultState_kpiIdsAreUnique() {
        let sut = WeeklyRecapInteractor()
        let ids = sut.state.kpis.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func test_shareText_staticHelperMatchesInstanceShareText() {
        let sut = WeeklyRecapInteractor()
        let fromHelper = WeeklyRecapModels.shareText(sut.state)
        let fromSut = sut.share()
        XCTAssertEqual(fromHelper, fromSut)
    }
}
