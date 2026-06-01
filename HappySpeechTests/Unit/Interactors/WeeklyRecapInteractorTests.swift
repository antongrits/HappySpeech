@testable import HappySpeech
import XCTest

// MARK: - WeeklyRecapInteractorTests
//
// WeeklyRecapInteractor — тонкий VIP (@Observable). Источник данных —
// реальный недельный агрегат через ProgressDashboardWorker (здесь замокан).
// По умолчанию состояние пустое (честное «пока нет занятий»), без фейк-KPI.

@MainActor
final class WeeklyRecapInteractorTests: XCTestCase {

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

    private func nonEmptyAggregate() -> DashboardAggregate {
        let daily = [
            DailyAccuracy(day: "Пн", accuracy: 0.6),
            DailyAccuracy(day: "Вт", accuracy: 0.8)
        ]
        return DashboardAggregate(
            summary: DashboardSummary(overallAccuracy: 0.7, streakDays: 5, totalMinutes: 57, totalStars: 18),
            daily: daily,
            weekly: [WeeklyAccuracy(weekIndex: 1, label: "Нед 1", accuracy: 0.7)],
            sounds: [SoundProgress(sound: "Р", accuracy: 0.7, sessions: 2, trend: .up)],
            soundHistory: ["Р": daily]
        )
    }

    // MARK: - Default state is honest empty

    func test_defaultState_isEmpty() {
        let sut = WeeklyRecapInteractor()
        XCTAssertTrue(sut.state.isEmpty)
        XCTAssertTrue(sut.state.kpis.isEmpty)
    }

    func test_share_emptyState_returnsNeutralText() {
        let sut = WeeklyRecapInteractor()
        let text = sut.share()
        XCTAssertFalse(text.isEmpty)
        XCTAssertFalse(text.contains("%"))
    }

    // MARK: - load() with real aggregate

    func test_load_withData_populatesRealKPIs() async {
        let sut = WeeklyRecapInteractor(worker: StubWorker(aggregate: nonEmptyAggregate()))
        await sut.load(childId: "child-1")
        XCTAssertFalse(sut.state.isEmpty)
        XCTAssertEqual(sut.state.kpis.count, 4)
        // Минуты приходят из реального агрегата (57).
        XCTAssertTrue(sut.state.kpis.contains { $0.value == "57" })
        // Точность 70%.
        XCTAssertTrue(sut.state.kpis.contains { $0.value == "70%" })
    }

    func test_load_emptyChildId_keepsEmpty() async {
        let sut = WeeklyRecapInteractor(worker: StubWorker(aggregate: nonEmptyAggregate()))
        await sut.load(childId: "")
        XCTAssertTrue(sut.state.isEmpty)
    }

    func test_load_emptyAggregate_keepsEmpty() async {
        let sut = WeeklyRecapInteractor(worker: StubWorker(aggregate: .empty))
        await sut.load(childId: "child-1")
        XCTAssertTrue(sut.state.isEmpty)
    }

    func test_load_noWorker_keepsEmpty() async {
        let sut = WeeklyRecapInteractor(worker: nil)
        await sut.load(childId: "child-1")
        XCTAssertTrue(sut.state.isEmpty)
    }

    // MARK: - share() with loaded data

    func test_share_withData_containsKPIValues() async {
        let sut = WeeklyRecapInteractor(worker: StubWorker(aggregate: nonEmptyAggregate()))
        await sut.load(childId: "child-1")
        let text = sut.share()
        for kpi in sut.state.kpis {
            XCTAssertTrue(text.contains(kpi.value), "Expected share text to contain KPI value '\(kpi.value)'")
        }
    }

    func test_shareText_staticHelperMatchesInstanceShareText() async {
        let sut = WeeklyRecapInteractor(worker: StubWorker(aggregate: nonEmptyAggregate()))
        await sut.load(childId: "child-1")
        let fromHelper = WeeklyRecapModels.shareText(sut.state)
        let fromSut = sut.share()
        XCTAssertEqual(fromHelper, fromSut)
    }

    // MARK: - makeState mapping

    func test_makeState_emptyAggregate_returnsEmpty() {
        let state = WeeklyRecapModels.makeState(from: .empty)
        XCTAssertTrue(state.isEmpty)
    }

    func test_makeState_kpiIdsAreUnique() {
        let state = WeeklyRecapModels.makeState(from: nonEmptyAggregate())
        let ids = state.kpis.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }
}
