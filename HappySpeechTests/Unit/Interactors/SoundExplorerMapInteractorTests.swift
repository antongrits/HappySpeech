@testable import HappySpeech
import XCTest

// MARK: - SoundExplorerMapInteractorTests
//
// SoundExplorerMapInteractor is a thin VIP MVP variant (@Observable, no separate
// Presenter/DisplayLogic). Tests verify filter logic and visible computed property.

@MainActor
final class SoundExplorerMapInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> SoundExplorerMapInteractor {
        SoundExplorerMapInteractor(childId: childId)
    }

    // MARK: - Initial state

    func test_initialFilter_isAll() {
        let sut = makeSUT()
        XCTAssertEqual(sut.filter, .all)
    }

    func test_initialSounds_matchesSeedSounds() {
        let sut = makeSUT()
        XCTAssertEqual(sut.sounds.count, SoundExplorerMapModels.seedSounds.count)
    }

    func test_initialVisible_containsAllSounds() {
        let sut = makeSUT()
        XCTAssertEqual(sut.visible.count, sut.sounds.count)
    }

    // MARK: - setFilter

    func test_setFilter_all_showsAllSounds() {
        let sut = makeSUT()
        sut.setFilter(.all)
        XCTAssertEqual(sut.visible.count, sut.sounds.count)
    }

    func test_setFilter_known_showsOnlyKnownSounds() {
        let sut = makeSUT()
        sut.setFilter(.known)
        let expected = sut.sounds.filter { $0.mastery == .known }.count
        XCTAssertEqual(sut.visible.count, expected)
    }

    func test_setFilter_learning_showsOnlyLearningSounds() {
        let sut = makeSUT()
        sut.setFilter(.learning)
        let expected = sut.sounds.filter { $0.mastery == .learning }.count
        XCTAssertEqual(sut.visible.count, expected)
    }

    func test_setFilter_untried_showsOnlyUntriedSounds() {
        let sut = makeSUT()
        sut.setFilter(.untried)
        let expected = sut.sounds.filter { $0.mastery == .untried }.count
        XCTAssertEqual(sut.visible.count, expected)
    }

    func test_setFilter_updatesFilterProperty() {
        let sut = makeSUT()
        sut.setFilter(.learning)
        XCTAssertEqual(sut.filter, .learning)
    }

    func test_setFilter_cycleAllFilters_noCrash() {
        let sut = makeSUT()
        for filter in SoundExplorerMapModels.MasteryFilter.allCases {
            sut.setFilter(filter)
            XCTAssertEqual(sut.filter, filter)
        }
    }

    // MARK: - visible

    func test_visible_knownFilter_containsOnlyKnownSounds() {
        let sut = makeSUT()
        sut.setFilter(.known)
        XCTAssertTrue(sut.visible.allSatisfy { $0.mastery == .known })
    }

    func test_visible_learningFilter_containsOnlyLearningSounds() {
        let sut = makeSUT()
        sut.setFilter(.learning)
        XCTAssertTrue(sut.visible.allSatisfy { $0.mastery == .learning })
    }

    func test_visible_untriedFilter_containsOnlyUntriedSounds() {
        let sut = makeSUT()
        sut.setFilter(.untried)
        XCTAssertTrue(sut.visible.allSatisfy { $0.mastery == .untried })
    }

    func test_childId_storedCorrectly() {
        let sut = makeSUT(childId: "test-child-42")
        XCTAssertEqual(sut.childId, "test-child-42")
    }
}
