@testable import HappySpeech
import XCTest

// MARK: - StoryRetellingProInteractorTests
//
// StoryRetellingProInteractor is a thin VIP MVP variant (@Observable). Its only
// action is select(_:), which records the chosen story id. Tests cover the seed
// catalogue (well-formedness, the completed/incomplete split) and the selection
// mutation, including re-selection.

@MainActor
final class StoryRetellingProInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> StoryRetellingProInteractor {
        StoryRetellingProInteractor(childId: childId)
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-retell")
        XCTAssertEqual(sut.childId, "kid-retell")
    }

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_noSelection() {
        let sut = makeSUT()
        XCTAssertNil(sut.state.selectedStoryId)
    }

    func test_initialState_storiesWellFormed() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.stories.isEmpty)
        XCTAssertEqual(Set(sut.state.stories.map(\.id)).count, sut.state.stories.count)
        for story in sut.state.stories {
            XCTAssertFalse(story.title.isEmpty)
            XCTAssertFalse(story.summary.isEmpty)
            XCTAssertGreaterThan(story.keyFactsCount, 0)
            XCTAssertGreaterThan(story.durationSeconds, 0)
        }
    }

    func test_initialState_hasBothCompletedAndIncompleteStories() {
        let sut = makeSUT()
        XCTAssertTrue(sut.state.stories.contains { $0.isCompleted })
        XCTAssertTrue(sut.state.stories.contains { !$0.isCompleted })
    }

    // MARK: - select

    func test_select_recordsStoryId() {
        let sut = makeSUT()
        let id = sut.state.stories[2].id
        sut.select(id)
        XCTAssertEqual(sut.state.selectedStoryId, id)
    }

    func test_select_doesNotMutateStories() {
        let sut = makeSUT()
        let before = sut.state.stories
        sut.select(sut.state.stories[0].id)
        XCTAssertEqual(sut.state.stories, before)
    }

    func test_select_canChangeSelection() {
        let sut = makeSUT()
        sut.select(sut.state.stories[0].id)
        let second = sut.state.stories[3].id
        sut.select(second)
        XCTAssertEqual(sut.state.selectedStoryId, second)
    }
}
