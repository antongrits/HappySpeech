@testable import HappySpeech
import XCTest

// MARK: - ConversationStartersParentInteractorTests
//
// ConversationStartersParentInteractor загружает курируемый контент и реально
// персистит избранное в UserDefaults. Тесты на изолированном suite.

@MainActor
final class ConversationStartersParentInteractorTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "convStarters.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func makeSUT() -> ConversationStartersParentInteractor {
        ConversationStartersParentInteractor(defaults: defaults)
    }

    func test_load_populatesQuestionsFromContent() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.questions.count, ConversationStartersContent.all.count)
        XCTAssertGreaterThan(sut.state.questions.count, 0)
    }

    func test_questionIds_areUnique() {
        let sut = makeSUT()
        XCTAssertEqual(Set(sut.state.questions.map(\.id)).count, sut.state.questions.count)
    }

    func test_noFavoritesByDefault() {
        let sut = makeSUT()
        XCTAssertTrue(sut.state.favorites.isEmpty)
    }

    func test_toggleFavorite_setsFlag() {
        let sut = makeSUT()
        let id = sut.state.questions[0].id
        sut.toggleFavorite(id)
        XCTAssertTrue(sut.state.questions.first { $0.id == id }?.isFavorite ?? false)
    }

    func test_toggleFavorite_twice_clears() {
        let sut = makeSUT()
        let id = sut.state.questions[0].id
        sut.toggleFavorite(id)
        sut.toggleFavorite(id)
        XCTAssertFalse(sut.state.questions.first { $0.id == id }?.isFavorite ?? true)
    }

    func test_favorite_persistsAcrossInstances() {
        let sut = makeSUT()
        let id = sut.state.questions[2].id
        sut.toggleFavorite(id)

        let reopened = makeSUT()
        XCTAssertTrue(reopened.state.questions.first { $0.id == id }?.isFavorite ?? false)
    }

    func test_toggleFavorite_unknownId_noop() {
        let sut = makeSUT()
        let before = sut.state.favorites.count
        sut.toggleFavorite("nonexistent")
        XCTAssertEqual(sut.state.favorites.count, before)
    }
}
