@testable import HappySpeech
import XCTest

// MARK: - KidGameScoreStoreTests
//
// Локальное хранилище рекордов звёзд детских мини-игр (per game + child).
// Тесты используют изолированный UserDefaults и проверяют монотонный рекорд,
// инкремент раундов, клампинг и no-op при пустом childId.

final class KidGameScoreStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "test.kidGameScore"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func makeSUT(game: String = "g", child: String = "c") -> KidGameScoreStore {
        KidGameScoreStore(defaults: defaults, gameKey: game, childId: child)
    }

    func test_initial_zero() {
        let sut = makeSUT()
        XCTAssertEqual(sut.bestStars, 0)
        XCTAssertEqual(sut.completedRounds, 0)
    }

    func test_recordCompletion_setsBestAndCountsRound() {
        let sut = makeSUT()
        XCTAssertTrue(sut.recordCompletion(stars: 2))
        XCTAssertEqual(sut.bestStars, 2)
        XCTAssertEqual(sut.completedRounds, 1)
    }

    func test_recordCompletion_recordOnlyGoesUp() {
        let sut = makeSUT()
        sut.recordCompletion(stars: 3)
        XCTAssertFalse(sut.recordCompletion(stars: 1)) // не новый рекорд
        XCTAssertEqual(sut.bestStars, 3)
        XCTAssertEqual(sut.completedRounds, 2)
    }

    func test_recordCompletion_clampsToThree() {
        let sut = makeSUT()
        sut.recordCompletion(stars: 99)
        XCTAssertEqual(sut.bestStars, 3)
    }

    func test_emptyChild_isNoOp() {
        let sut = makeSUT(child: "")
        XCTAssertFalse(sut.recordCompletion(stars: 3))
        XCTAssertEqual(sut.bestStars, 0)
        XCTAssertEqual(sut.completedRounds, 0)
    }

    func test_separateGamesAndChildren_isolated() {
        let a = makeSUT(game: "bingo", child: "kid-1")
        let b = makeSUT(game: "memory", child: "kid-1")
        a.recordCompletion(stars: 3)
        XCTAssertEqual(b.bestStars, 0)
    }
}
