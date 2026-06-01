@testable import HappySpeech
import XCTest

// MARK: - StoryEndingMakerInteractorTests
//
// StoryEndingMakerInteractor грузит картинки-концовки из словаря через worker,
// ведёт трёхфазный поток choosing → recording → saving → saved и персистит
// счётчик сохранённых концовок. Тесты на mock-worker и изолированном suite.

@MainActor
final class StoryEndingMakerInteractorTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "storyEnding.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private final class MockWorker: StoryEndingMakerWorkerProtocol {
        let cards: [StoryEndingMakerModels.PictureCard]
        init(cards: [StoryEndingMakerModels.PictureCard]) { self.cards = cards }
        func buildCards(childId: String) async -> [StoryEndingMakerModels.PictureCard] { cards }
    }

    private func makeSUT(childId: String = "child-1") -> StoryEndingMakerInteractor {
        let worker = MockWorker(cards: [
            .init(id: "c1", asset: "word_fox", label: "Лиса"),
            .init(id: "c2", asset: nil, label: "Заяц"),
            .init(id: "c3", asset: "word_tree", label: "Дерево")
        ])
        return StoryEndingMakerInteractor(childId: childId, worker: worker, defaults: defaults)
    }

    func test_load_populatesCardsAndChoosing() async {
        let sut = makeSUT()
        await sut.load()
        XCTAssertTrue(sut.state.isLoaded)
        XCTAssertEqual(sut.state.cards.count, 3)
        XCTAssertEqual(sut.state.phase, .choosing)
    }

    func test_load_withoutWorker_marksEmpty() async {
        let sut = StoryEndingMakerInteractor(childId: "c", defaults: defaults)
        await sut.load()
        XCTAssertTrue(sut.state.isLoaded)
        XCTAssertTrue(sut.state.isEmpty)
    }

    func test_select_movesToRecording() async {
        let sut = makeSUT()
        await sut.load()
        sut.select("c1")
        XCTAssertEqual(sut.state.selectedId, "c1")
        XCTAssertEqual(sut.state.phase, .recording)
    }

    func test_save_incrementsAndPersistsCount() async {
        let sut = makeSUT()
        await sut.load()
        sut.select("c1")
        sut.save()
        // save() гоняет async-Task; ждём перехода в .saved.
        try? await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(sut.state.phase, .saved)
        XCTAssertEqual(sut.state.savedCount, 1)

        // Новый интерактор на том же suite видит сохранённый счётчик.
        let reopened = makeSUT()
        await reopened.load()
        XCTAssertEqual(reopened.state.savedCount, 1)
    }

    func test_reset_returnsToChoosing() async {
        let sut = makeSUT()
        await sut.load()
        sut.select("c1")
        sut.reset()
        XCTAssertEqual(sut.state.phase, .choosing)
        XCTAssertNil(sut.state.selectedId)
    }

    func test_save_withoutRecordingPhase_noop() async {
        let sut = makeSUT()
        await sut.load()
        sut.save() // phase == .choosing
        XCTAssertEqual(sut.state.phase, .choosing)
        XCTAssertEqual(sut.state.savedCount, 0)
    }
}
