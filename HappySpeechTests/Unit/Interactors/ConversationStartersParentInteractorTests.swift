@testable import HappySpeech
import XCTest

// MARK: - ConversationStartersParentInteractorTests
//
// ConversationStartersParentInteractor is a thin VIP MVP variant (@Observable). It
// holds a fixed list of conversation-starter questions; toggleFavorite(_:) flips
// the favourite flag on the matching question (ignoring unknown ids). Tests cover
// the seed (well-formedness, the pre-favourited entries, category coverage) and
// the toggle, including the unknown-id guard.
// (Category.title/.color maps are purely presentational — intentionally skipped.)

@MainActor
final class ConversationStartersParentInteractorTests: XCTestCase {

    private func makeSUT() -> ConversationStartersParentInteractor {
        ConversationStartersParentInteractor()
    }

    // MARK: - Initial state

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_questionsWellFormed() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.questions.isEmpty)
        XCTAssertEqual(Set(sut.state.questions.map(\.id)).count, sut.state.questions.count)
        for q in sut.state.questions {
            XCTAssertFalse(q.text.isEmpty)
        }
    }

    func test_initialState_hasSomePreFavorited() {
        let sut = makeSUT()
        XCTAssertTrue(sut.state.questions.contains { $0.isFavorite })
    }

    func test_initialState_coversAllCategories() {
        let sut = makeSUT()
        let present = Set(sut.state.questions.map(\.category))
        XCTAssertEqual(present, Set(ConversationStartersParentModels.Category.allCases))
    }

    // MARK: - toggleFavorite

    func test_toggleFavorite_flipsFlag() {
        let sut = makeSUT()
        let target = sut.state.questions.first { !$0.isFavorite }!
        sut.toggleFavorite(target.id)
        XCTAssertEqual(sut.state.questions.first { $0.id == target.id }?.isFavorite, true)
    }

    func test_toggleFavorite_twice_restoresOriginal() {
        let sut = makeSUT()
        let target = sut.state.questions[3]
        let before = target.isFavorite
        sut.toggleFavorite(target.id)
        sut.toggleFavorite(target.id)
        XCTAssertEqual(sut.state.questions.first { $0.id == target.id }?.isFavorite, before)
    }

    func test_toggleFavorite_unfavorites() {
        let sut = makeSUT()
        let target = sut.state.questions.first { $0.isFavorite }!
        sut.toggleFavorite(target.id)
        XCTAssertEqual(sut.state.questions.first { $0.id == target.id }?.isFavorite, false)
    }

    func test_toggleFavorite_onlyAffectsTarget() {
        let sut = makeSUT()
        let target = sut.state.questions[5]
        let othersBefore = sut.state.questions.filter { $0.id != target.id }
        sut.toggleFavorite(target.id)
        let othersAfter = sut.state.questions.filter { $0.id != target.id }
        XCTAssertEqual(othersBefore, othersAfter)
    }

    func test_toggleFavorite_unknownId_noChange() {
        let sut = makeSUT()
        let before = sut.state.questions
        sut.toggleFavorite("does-not-exist")
        XCTAssertEqual(sut.state.questions, before)
    }
}
