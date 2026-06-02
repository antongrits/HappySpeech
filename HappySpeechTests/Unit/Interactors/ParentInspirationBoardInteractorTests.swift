@testable import HappySpeech
import XCTest

// MARK: - ParentInspirationBoardInteractorTests
//
// «Доска вдохновения»: круговая карусель цитат (ParentInspirationBoardContent);
// next/previous циклятся по visibleQuotes, toggleFavorite переключает избранное
// и персистит его. Поддерживается фильтр «только избранное». Тесты используют
// изолированный UserDefaults.

@MainActor
final class ParentInspirationBoardInteractorTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "test.parentInspiration"

    override func setUp() async throws {
        try await super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        try await super.tearDown()
    }

    private func makeSUT() -> ParentInspirationBoardInteractor {
        ParentInspirationBoardInteractor(defaults: defaults)
    }

    private var count: Int { ParentInspirationBoardContent.quotes.count }

    // MARK: - Initial state

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

    func test_initialState_noFavoritesWithFreshStore() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.favoritesCount, 0)
    }

    // MARK: - next / previous

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

    func test_previous_fromStart_wrapsToLast() {
        let sut = makeSUT()
        sut.previous()
        XCTAssertEqual(sut.state.currentIndex, count - 1)
    }

    func test_nextPrevious_returnsToOrigin() {
        let sut = makeSUT()
        sut.next()
        sut.previous()
        XCTAssertEqual(sut.state.currentIndex, 0)
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

    func test_toggleFavorite_persistsAcrossInstances() {
        let sut1 = makeSUT()
        let favId = sut1.state.current!.id
        sut1.toggleFavorite()
        let sut2 = makeSUT()
        XCTAssertEqual(sut2.state.quotes.first { $0.id == favId }?.isFavorite, true)
        XCTAssertEqual(sut2.state.favoritesCount, 1)
    }

    // MARK: - favorites filter

    func test_favoritesFilter_showsOnlyFavorites() {
        let sut = makeSUT()
        sut.toggleFavorite()          // делаем первую цитату избранной
        sut.toggleFavoritesFilter()   // включаем фильтр
        XCTAssertTrue(sut.state.favoritesOnly)
        XCTAssertEqual(sut.state.visibleQuotes.count, 1)
    }

    func test_favoritesFilter_emptyWhenNoFavorites() {
        let sut = makeSUT()
        sut.toggleFavoritesFilter()
        XCTAssertTrue(sut.state.visibleQuotes.isEmpty)
        XCTAssertNil(sut.state.current)
    }

    // MARK: - current computed

    func test_current_outOfBounds_isNil() {
        let state = ParentInspirationBoardModels.ViewState(
            quotes: ParentInspirationBoardContent.quotes,
            currentIndex: 999
        )
        XCTAssertNil(state.current)
    }
}
