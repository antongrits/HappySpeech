@testable import HappySpeech
import XCTest

// MARK: - FamilyLeaderboardPresenterTests
//
// Phase 2.6 batch 2 v25 — покрытие FamilyLeaderboardPresenter (0% → цель ≥90%).

@MainActor
final class FamilyLeaderboardPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: FamilyLeaderboardDisplayLogic {
        var loadVM: FamilyLeaderboardModels.Load.ViewModel?
        func displayLoad(viewModel: FamilyLeaderboardModels.Load.ViewModel) async { loadVM = viewModel }
    }

    private func makeSUT() -> (FamilyLeaderboardPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = FamilyLeaderboardPresenter(displayLogic: spy)
        return (presenter, spy)
    }

    private func makeEntry(
        id: String = UUID().uuidString,
        childName: String = "Маша",
        sessionCount: Int = 5,
        totalScore: Double = 100.0,
        avgAccuracy: Double = 0.8,
        currentStreak: Int = 3
    ) -> FamilyLeaderboardModels.Load.Entry {
        FamilyLeaderboardModels.Load.Entry(
            id: id,
            childName: childName,
            avatarStyle: "butterfly",
            colorTheme: "#FF6B6B",
            sessionCount: sessionCount,
            totalScore: totalScore,
            avgAccuracy: avgAccuracy,
            currentStreak: currentStreak
        )
    }

    // MARK: - presentLoad: empty

    func test_presentLoad_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            entries: [],
            period: .week,
            totalSessionsAcrossFamily: 0,
            weekStartDate: Date()
        ))
        XCTAssertNotNil(spy.loadVM)
    }

    func test_presentLoad_empty_isEmptyTrue() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            entries: [],
            period: .week,
            totalSessionsAcrossFamily: 0,
            weekStartDate: Date()
        ))
        XCTAssertTrue(spy.loadVM?.isEmpty ?? false)
    }

    func test_presentLoad_titleNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            entries: [],
            period: .week,
            totalSessionsAcrossFamily: 0,
            weekStartDate: Date()
        ))
        XCTAssertFalse(spy.loadVM?.title.isEmpty ?? true)
    }

    func test_presentLoad_empty_subtitleNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            entries: [],
            period: .week,
            totalSessionsAcrossFamily: 0,
            weekStartDate: Date()
        ))
        XCTAssertFalse(spy.loadVM?.subtitle.isEmpty ?? true)
    }

    func test_presentLoad_withEntries_subtitleNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            entries: [makeEntry()],
            period: .week,
            totalSessionsAcrossFamily: 5,
            weekStartDate: Date()
        ))
        XCTAssertFalse(spy.loadVM?.subtitle.isEmpty ?? true)
    }

    func test_presentLoad_periodLabelNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            entries: [],
            period: .month,
            totalSessionsAcrossFamily: 0,
            weekStartDate: Date()
        ))
        XCTAssertFalse(spy.loadVM?.periodLabel.isEmpty ?? true)
    }

    // MARK: - Medal assignment

    func test_presentLoad_firstPlace_goldMedal() async {
        let (sut, spy) = makeSUT()
        let entries = [makeEntry(id: "c1"), makeEntry(id: "c2"), makeEntry(id: "c3")]
        await sut.presentLoad(response: .init(
            entries: entries,
            period: .week,
            totalSessionsAcrossFamily: 15,
            weekStartDate: Date()
        ))
        XCTAssertEqual(spy.loadVM?.rows.first?.medal, .gold)
    }

    func test_presentLoad_secondPlace_silverMedal() async {
        let (sut, spy) = makeSUT()
        let entries = [makeEntry(id: "c1"), makeEntry(id: "c2"), makeEntry(id: "c3")]
        await sut.presentLoad(response: .init(
            entries: entries,
            period: .week,
            totalSessionsAcrossFamily: 15,
            weekStartDate: Date()
        ))
        let rows = spy.loadVM?.rows ?? []
        XCTAssertEqual(rows[safe: 1]?.medal, .silver)
    }

    func test_presentLoad_thirdPlace_bronzeMedal() async {
        let (sut, spy) = makeSUT()
        let entries = [makeEntry(id: "c1"), makeEntry(id: "c2"), makeEntry(id: "c3")]
        await sut.presentLoad(response: .init(
            entries: entries,
            period: .week,
            totalSessionsAcrossFamily: 15,
            weekStartDate: Date()
        ))
        let rows = spy.loadVM?.rows ?? []
        XCTAssertEqual(rows[safe: 2]?.medal, .bronze)
    }

    func test_presentLoad_fourthPlace_noMedal() async {
        let (sut, spy) = makeSUT()
        let entries = [makeEntry(id: "c1"), makeEntry(id: "c2"), makeEntry(id: "c3"), makeEntry(id: "c4")]
        await sut.presentLoad(response: .init(
            entries: entries,
            period: .week,
            totalSessionsAcrossFamily: 20,
            weekStartDate: Date()
        ))
        let rows = spy.loadVM?.rows ?? []
        XCTAssertNil(rows[safe: 3]?.medal)
    }

    func test_presentLoad_firstPlace_isLeaderTrue() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            entries: [makeEntry(id: "c1"), makeEntry(id: "c2")],
            period: .week,
            totalSessionsAcrossFamily: 10,
            weekStartDate: Date()
        ))
        XCTAssertTrue(spy.loadVM?.rows.first?.isLeader ?? false)
    }

    func test_presentLoad_secondPlace_isLeaderFalse() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            entries: [makeEntry(id: "c1"), makeEntry(id: "c2")],
            period: .week,
            totalSessionsAcrossFamily: 10,
            weekStartDate: Date()
        ))
        let rows = spy.loadVM?.rows ?? []
        XCTAssertFalse(rows[safe: 1]?.isLeader ?? true)
    }

    func test_presentLoad_rowA11yLabelNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            entries: [makeEntry(childName: "Маша", sessionCount: 5, avgAccuracy: 0.8)],
            period: .week,
            totalSessionsAcrossFamily: 5,
            weekStartDate: Date()
        ))
        XCTAssertFalse(spy.loadVM?.rows.first?.accessibilityLabel.isEmpty ?? true)
    }

    func test_presentLoad_singleEntry_isEmptyFalse() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            entries: [makeEntry()],
            period: .week,
            totalSessionsAcrossFamily: 5,
            weekStartDate: Date()
        ))
        XCTAssertFalse(spy.loadVM?.isEmpty ?? true)
    }
}

// MARK: - Collection safe subscript helper

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
