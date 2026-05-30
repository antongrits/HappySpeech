@testable import HappySpeech
import XCTest

// MARK: - ParentInspirationBoardInteractorTests
//
// ParentInspirationBoardInteractor is a thin VIP MVP variant (@Observable). It is a
// circular carousel of quotes: next/previous wrap around modulo the pool size and
// toggleFavorite flips the favourite flag on the current quote. Tests cover the
// wrap-around arithmetic (forwards and backwards), the favourite toggle and the
// `current` bounds computed.

@MainActor
final class ParentInspirationBoardInteractorTests: XCTestCase {

    private func makeSUT() -> ParentInspirationBoardInteractor {
        ParentInspirationBoardInteractor()
    }

    private var count: Int { ParentInspirationBoardModels.ViewState.initial.quotes.count }

    // MARK: - Initial state

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_startsAtFirstQuote() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.currentIndex, 0)
        XCTAssertEqual(sut.state.current?.id, sut.state.quotes[0].id)
    }

    func test_initialState_quotesWellFormed() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.quotes.isEmpty)
        XCTAssertEqual(Set(sut.state.quotes.map(\.id)).count, sut.state.quotes.count)
        for quote in sut.state.quotes {
            XCTAssertFalse(quote.text.isEmpty)
            XCTAssertFalse(quote.author.isEmpty)
        }
    }

    // MARK: - next

    func test_next_advancesIndex() {
        let sut = makeSUT()
        sut.next()
        XCTAssertEqual(sut.state.currentIndex, 1)
    }

    func test_next_wrapsAroundAtEnd() {
        let sut = makeSUT()
        for _ in 0..<count { sut.next() }
        XCTAssertEqual(sut.state.currentIndex, 0)
    }

    // MARK: - previous

    func test_previous_fromStart_wrapsToLast() {
        let sut = makeSUT()
        sut.previous()
        XCTAssertEqual(sut.state.currentIndex, count - 1)
    }

    func test_previous_undoesNext() {
        let sut = makeSUT()
        sut.next()
        sut.next()
        sut.previous()
        XCTAssertEqual(sut.state.currentIndex, 1)
    }

    func test_nextPrevious_returnsToOrigin() {
        let sut = makeSUT()
        sut.next()
        sut.previous()
        XCTAssertEqual(sut.state.currentIndex, 0)
    }

    // MARK: - current computed

    func test_current_tracksIndex() {
        let sut = makeSUT()
        sut.next()
        XCTAssertEqual(sut.state.current?.id, sut.state.quotes[1].id)
    }

    func test_current_outOfBounds_isNil() {
        let state = ParentInspirationBoardModels.ViewState(
            quotes: ParentInspirationBoardModels.ViewState.initial.quotes,
            currentIndex: 999
        )
        XCTAssertNil(state.current)
    }

    // MARK: - toggleFavorite

    func test_toggleFavorite_flipsCurrentQuote() {
        let sut = makeSUT()
        let before = sut.state.current?.isFavorite ?? false
        sut.toggleFavorite()
        XCTAssertEqual(sut.state.current?.isFavorite, !before)
    }

    func test_toggleFavorite_twice_restoresOriginal() {
        let sut = makeSUT()
        let before = sut.state.current?.isFavorite ?? false
        sut.toggleFavorite()
        sut.toggleFavorite()
        XCTAssertEqual(sut.state.current?.isFavorite, before)
    }

    func test_toggleFavorite_onlyAffectsCurrentQuote() {
        let sut = makeSUT()
        let currentId = sut.state.current!.id
        let othersBefore = sut.state.quotes.filter { $0.id != currentId }
        sut.toggleFavorite()
        let othersAfter = sut.state.quotes.filter { $0.id != currentId }
        XCTAssertEqual(othersBefore, othersAfter)
    }

    func test_toggleFavorite_afterNext_affectsNewCurrent() {
        let sut = makeSUT()
        sut.next()
        let id = sut.state.current!.id
        let before = sut.state.current!.isFavorite
        sut.toggleFavorite()
        XCTAssertEqual(sut.state.quotes.first { $0.id == id }?.isFavorite, !before)
    }
}
