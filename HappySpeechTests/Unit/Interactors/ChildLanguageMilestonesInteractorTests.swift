@testable import HappySpeech
import XCTest

// MARK: - ChildLanguageMilestonesInteractorTests
//
// ChildLanguageMilestonesInteractor is a thin VIP MVP variant (@Observable). It
// holds a checklist of language milestones grouped by Section; toggle(_:) flips
// the `isAchieved` flag on the matching item (ignoring unknown ids). Tests cover
// the seed well-formedness, the toggle (incl. unknown-id guard, isolation), and
// the derived state (overallProgress, items(in:)).
// (Section.title/.iconSystemName maps are purely presentational — intentionally skipped.)

@MainActor
final class ChildLanguageMilestonesInteractorTests: XCTestCase {

    /// Изолированный UserDefaults на каждый SUT, чтобы персистентные отметки
    /// не протекали между тестами.
    private func makeSUT() -> ChildLanguageMilestonesInteractor {
        let suite = UserDefaults(suiteName: "test.milestones.\(UUID().uuidString)")!
        return ChildLanguageMilestonesInteractor(childId: "test-child", defaults: suite)
    }

    // MARK: - Initial state

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_itemsWellFormed() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.items.isEmpty)
        XCTAssertEqual(Set(sut.state.items.map(\.id)).count, sut.state.items.count)
        for item in sut.state.items {
            XCTAssertFalse(item.title.isEmpty)
        }
    }

    func test_initialState_coversAllSections() {
        let sut = makeSUT()
        let present = Set(sut.state.items.map(\.section))
        XCTAssertEqual(present, Set(ChildLanguageMilestonesModels.Section.allCases))
    }

    func test_initialState_ageBandNotEmpty() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.ageBand.isEmpty)
    }

    // MARK: - toggle

    func test_toggle_flipsAchievedFlag() {
        let sut = makeSUT()
        let target = sut.state.items.first { !$0.isAchieved }!
        sut.toggle(target.id)
        XCTAssertEqual(sut.state.items.first { $0.id == target.id }?.isAchieved, true)
    }

    func test_toggle_twice_restoresOriginal() {
        let sut = makeSUT()
        let target = sut.state.items[2]
        let before = target.isAchieved
        sut.toggle(target.id)
        sut.toggle(target.id)
        XCTAssertEqual(sut.state.items.first { $0.id == target.id }?.isAchieved, before)
    }

    func test_toggle_unachievesAchievedItem() {
        let sut = makeSUT()
        // Стартово все вехи НЕ отмечены — сначала отмечаем, затем снимаем.
        let target = sut.state.items[0]
        sut.toggle(target.id)
        XCTAssertEqual(sut.state.items.first { $0.id == target.id }?.isAchieved, true)
        sut.toggle(target.id)
        XCTAssertEqual(sut.state.items.first { $0.id == target.id }?.isAchieved, false)
    }

    // MARK: - Persistence

    func test_initialState_allUnachieved() {
        // Чек-лист стартует пустым: отметки ставит родитель, не данные.
        let sut = makeSUT()
        XCTAssertTrue(sut.state.items.allSatisfy { !$0.isAchieved })
        XCTAssertEqual(sut.state.overallProgress, 0)
    }

    func test_toggle_persistsAcrossInstances() {
        let suite = UserDefaults(suiteName: "test.milestones.persist.\(UUID().uuidString)")!
        let sut1 = ChildLanguageMilestonesInteractor(childId: "child-x", defaults: suite)
        sut1.toggle("c1")
        sut1.toggle("s2")
        // Новый интерактор того же ребёнка читает сохранённые отметки.
        let sut2 = ChildLanguageMilestonesInteractor(childId: "child-x", defaults: suite)
        XCTAssertEqual(sut2.state.items.first { $0.id == "c1" }?.isAchieved, true)
        XCTAssertEqual(sut2.state.items.first { $0.id == "s2" }?.isAchieved, true)
        XCTAssertEqual(sut2.state.items.first { $0.id == "c2" }?.isAchieved, false)
    }

    func test_toggle_onlyAffectsTarget() {
        let sut = makeSUT()
        let target = sut.state.items[4]
        let othersBefore = sut.state.items.filter { $0.id != target.id }
        sut.toggle(target.id)
        let othersAfter = sut.state.items.filter { $0.id != target.id }
        XCTAssertEqual(othersBefore, othersAfter)
    }

    func test_toggle_unknownId_noChange() {
        let sut = makeSUT()
        let before = sut.state.items
        sut.toggle("does-not-exist")
        XCTAssertEqual(sut.state.items, before)
    }

    // MARK: - Derived state

    func test_overallProgress_matchesAchievedFraction() {
        let sut = makeSUT()
        let total = sut.state.items.count
        let done = sut.state.items.filter(\.isAchieved).count
        XCTAssertEqual(sut.state.overallProgress, Double(done) / Double(total), accuracy: 0.0001)
    }

    func test_overallProgress_increasesAfterAchievingItem() {
        let sut = makeSUT()
        let before = sut.state.overallProgress
        let target = sut.state.items.first { !$0.isAchieved }!
        sut.toggle(target.id)
        XCTAssertGreaterThan(sut.state.overallProgress, before)
    }

    func test_overallProgress_emptyItems_isZero() {
        var state = ChildLanguageMilestonesModels.ViewState.initial
        state.items = []
        XCTAssertEqual(state.overallProgress, 0)
    }

    func test_itemsInSection_returnsOnlyThatSection() {
        let sut = makeSUT()
        for section in ChildLanguageMilestonesModels.Section.allCases {
            let subset = sut.state.items(in: section)
            XCTAssertTrue(subset.allSatisfy { $0.section == section })
            XCTAssertFalse(subset.isEmpty)
        }
    }

    func test_itemsInSection_partitionsAllItems() {
        let sut = makeSUT()
        let recombined = ChildLanguageMilestonesModels.Section.allCases
            .flatMap { sut.state.items(in: $0) }
        XCTAssertEqual(recombined.count, sut.state.items.count)
    }
}
