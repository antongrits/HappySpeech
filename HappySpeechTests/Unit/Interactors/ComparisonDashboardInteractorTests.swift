import XCTest
@testable import HappySpeech

// MARK: - ComparisonDashboardInteractorTests
//
// Strategy: wire real ComparisonDashboardPresenter → ComparisonDashboardViewModel.
// The interactor holds `weak var presenter`, so we use `let c = makeSUT()` and
// access all elements by label — this keeps the presenter alive across all awaits.

@MainActor
final class ComparisonDashboardInteractorTests: XCTestCase {

    private func makeSUT(
        children: [ChildProfileDTO]? = nil,
        sessions: [SessionDTO]? = nil
    ) -> (
        sut: ComparisonDashboardInteractor,
        childRepo: SpyChildRepository,
        presenter: ComparisonDashboardPresenter,
        viewModel: ComparisonDashboardViewModel
    ) {
        let childRepo = SpyChildRepository(children: children ?? [
            TestDataBuilder.childProfile(id: "c1", name: "Маша", progressSummary: ["Р": 0.8]),
            TestDataBuilder.childProfile(id: "c2", name: "Ваня", progressSummary: ["Ш": 0.6])
        ])
        let sessionRepo = SpySessionRepository(sessions: sessions ?? [
            TestDataBuilder.session(id: "s1", childId: "c1"),
            TestDataBuilder.session(id: "s2", childId: "c2")
        ])
        let sut = ComparisonDashboardInteractor(
            childRepository: childRepo,
            sessionRepository: sessionRepo
        )
        let presenter = ComparisonDashboardPresenter()
        let viewModel = ComparisonDashboardViewModel()
        presenter.viewModel = viewModel
        sut.presenter = presenter
        return (sut, childRepo, presenter, viewModel)
    }

    // MARK: - load

    func test_load_setsIsLoadingFalse_afterCompletion() async {
        let c = makeSUT()
        await c.sut.load(ComparisonDashboard.LoadRequest(childIds: []))
        XCTAssertFalse(c.viewModel.isLoading)
    }

    func test_load_emptyChildIds_populatesChildren() async {
        let c = makeSUT()
        await c.sut.load(ComparisonDashboard.LoadRequest(childIds: []))
        XCTAssertGreaterThan(c.viewModel.children.count, 0)
    }

    func test_load_specificChildIds_returns1Child() async {
        let c = makeSUT()
        await c.sut.load(ComparisonDashboard.LoadRequest(childIds: ["c1"]))
        XCTAssertEqual(c.viewModel.children.count, 1)
    }

    func test_load_childrenSortedAlphabetically() async {
        let c = makeSUT()
        await c.sut.load(ComparisonDashboard.LoadRequest(childIds: []))
        let names = c.viewModel.children.map(\.name)
        XCTAssertEqual(names, names.sorted())
    }

    func test_load_onChildRepoError_setsErrorMessage() async {
        let c = makeSUT()
        c.childRepo.shouldFail = true
        await c.sut.load(ComparisonDashboard.LoadRequest(childIds: []))
        XCTAssertNotNil(c.viewModel.errorMessage)
    }

    func test_load_noChildren_childCountIsZero() async {
        let c = makeSUT(children: [])
        await c.sut.load(ComparisonDashboard.LoadRequest(childIds: []))
        XCTAssertEqual(c.viewModel.children.count, 0)
    }

    func test_load_eachChild_has7WeeklySuccessPoints() async {
        let c = makeSUT()
        await c.sut.load(ComparisonDashboard.LoadRequest(childIds: ["c1"]))
        XCTAssertEqual(c.viewModel.children.first?.weeklySuccess.count, 7)
    }

    func test_load_eachChild_has7DailyPracticePoints() async {
        let c = makeSUT()
        await c.sut.load(ComparisonDashboard.LoadRequest(childIds: ["c1"]))
        XCTAssertEqual(c.viewModel.children.first?.dailyPracticeMinutes.count, 7)
    }

    // MARK: - filterByPeriod

    func test_filterByPeriod_30Days_doesNotCrash() async {
        let c = makeSUT()
        await c.sut.load(ComparisonDashboard.LoadRequest(childIds: []))
        await c.sut.filterByPeriod(ComparisonDashboard.FilterByPeriodRequest(period: .last30Days))
    }

    func test_filterByPeriod_callsPresentLoaded() async {
        let c = makeSUT()
        await c.sut.load(ComparisonDashboard.LoadRequest(childIds: []))
        await c.sut.filterByPeriod(ComparisonDashboard.FilterByPeriodRequest(period: .last30Days))
        XCTAssertFalse(c.viewModel.isLoading)
    }

    // MARK: - filterBySound

    func test_filterBySound_nil_doesNotChangeChildCount() async {
        let c = makeSUT()
        await c.sut.load(ComparisonDashboard.LoadRequest(childIds: []))
        let beforeCount = c.viewModel.children.count
        await c.sut.filterBySound(ComparisonDashboard.FilterBySoundRequest(sound: nil))
        XCTAssertEqual(c.viewModel.children.count, beforeCount)
    }

    func test_filterBySound_nonNil_doesNotCrash() async {
        let c = makeSUT()
        await c.sut.load(ComparisonDashboard.LoadRequest(childIds: []))
        await c.sut.filterBySound(ComparisonDashboard.FilterBySoundRequest(sound: "Р"))
    }

    // MARK: - computeRanking

    func test_computeRanking_empty_returnsEmpty() {
        let c = makeSUT()
        XCTAssertTrue(c.sut.computeRanking().isEmpty)
    }

    func test_computeRanking_afterLoad_returnsAllChildren() async {
        let c = makeSUT()
        await c.sut.load(ComparisonDashboard.LoadRequest(childIds: []))
        XCTAssertEqual(c.sut.computeRanking().count, 2)
    }

    func test_computeRanking_rankStartsAt1() async {
        let c = makeSUT()
        await c.sut.load(ComparisonDashboard.LoadRequest(childIds: []))
        XCTAssertEqual(c.sut.computeRanking().first?.rank, 1)
    }

    func test_computeRanking_ranksAreConsecutive() async {
        let c = makeSUT()
        await c.sut.load(ComparisonDashboard.LoadRequest(childIds: []))
        let ranks = c.sut.computeRanking().map(\.rank)
        XCTAssertEqual(ranks, Array(1...ranks.count))
    }

    // MARK: - Period.days

    func test_period_last7Days_returns7() {
        XCTAssertEqual(ComparisonDashboard.Period.last7Days.days, 7)
    }

    func test_period_last30Days_returns30() {
        XCTAssertEqual(ComparisonDashboard.Period.last30Days.days, 30)
    }

    func test_period_last90Days_returns90() {
        XCTAssertEqual(ComparisonDashboard.Period.last90Days.days, 90)
    }

    // MARK: - ViewModel helpers

    func test_viewModel_hasData_trueAfterLoad() async {
        let c = makeSUT()
        await c.sut.load(ComparisonDashboard.LoadRequest(childIds: []))
        XCTAssertTrue(c.viewModel.hasData)
    }

    func test_viewModel_allSounds_nonEmptyAfterLoad() async {
        let c = makeSUT()
        await c.sut.load(ComparisonDashboard.LoadRequest(childIds: []))
        XCTAssertFalse(c.viewModel.allSounds.isEmpty)
    }
}
