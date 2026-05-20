@testable import HappySpeech
import XCTest

// MARK: - Stub Presenter

@MainActor
private final class StubSpeechNormsPresenter: SpeechNormsEncyclopediaPresentationLogic, @unchecked Sendable {
    var lastResponse: SpeechNormsEncyclopediaModels.Load.Response?
    var presentCount = 0

    func presentLoad(response: SpeechNormsEncyclopediaModels.Load.Response) async {
        lastResponse = response
        presentCount += 1
    }
}

// MARK: - Mock Worker

@MainActor
private final class MockSpeechNormsWorker: SpeechNormsEncyclopediaWorkerProtocol, @unchecked Sendable {
    var stubbed: [NormCard]

    init(stubbed: [NormCard]) {
        self.stubbed = stubbed
    }

    func loadCards() async -> [NormCard] {
        stubbed
    }
}

// MARK: - Interactor Tests

@MainActor
final class SpeechNormsEncyclopediaInteractorTests: XCTestCase {

    private func makeCards() -> [NormCard] {
        [
            NormCard(id: "5-sounds", age: .five, axis: .sounds,
                     title: "Звуки 5", summary: "С", body: "B", sources: []),
            NormCard(id: "5-grammar", age: .five, axis: .grammar,
                     title: "Грамматика 5", summary: "С", body: "B", sources: []),
            NormCard(id: "6-sounds", age: .six, axis: .sounds,
                     title: "Звуки 6", summary: "С", body: "B", sources: []),
            NormCard(id: "7-sounds", age: .seven, axis: .sounds,
                     title: "Звуки 7 уникальный", summary: "С", body: "B", sources: []),
            NormCard(id: "7-redflag", age: .seven, axis: .redflags,
                     title: "Флаг 7", summary: "Внимание", body: "B", sources: [])
        ]
    }

    private func makeSUT() -> (SpeechNormsEncyclopediaInteractor, StubSpeechNormsPresenter, MockSpeechNormsWorker) {
        let worker = MockSpeechNormsWorker(stubbed: makeCards())
        let sut = SpeechNormsEncyclopediaInteractor(worker: worker)
        let presenter = StubSpeechNormsPresenter()
        sut.presenter = presenter
        return (sut, presenter, worker)
    }

    func test_load_filtersByInitialAge() async {
        let (sut, presenter, _) = makeSUT()
        await sut.load(request: .init(initialAge: .six, query: ""))
        XCTAssertEqual(presenter.lastResponse?.cards.count, 1)
        XCTAssertEqual(presenter.lastResponse?.selectedAge, .six)
    }

    func test_load_passesQueryThrough() async {
        let (sut, presenter, _) = makeSUT()
        await sut.load(request: .init(initialAge: .six, query: "звук"))
        XCTAssertEqual(presenter.lastResponse?.query, "звук")
    }

    func test_selectAge_switchesFilter() async {
        let (sut, presenter, _) = makeSUT()
        await sut.load(request: .init(initialAge: .five, query: ""))
        XCTAssertEqual(presenter.lastResponse?.cards.count, 2)

        await sut.selectAge(request: .init(age: .seven))
        XCTAssertEqual(presenter.lastResponse?.selectedAge, .seven)
        XCTAssertEqual(presenter.lastResponse?.cards.count, 2)
    }

    func test_selectAge_sameAge_doesNotRepresent() async {
        let (sut, presenter, _) = makeSUT()
        await sut.load(request: .init(initialAge: .six, query: ""))
        let initialCount = presenter.presentCount

        await sut.selectAge(request: .init(age: .six))
        XCTAssertEqual(presenter.presentCount, initialCount,
                       "Selecting the already-selected age should be a no-op")
    }

    func test_search_filtersBySubstring() async {
        let (sut, presenter, _) = makeSUT()
        await sut.load(request: .init(initialAge: .seven, query: ""))
        XCTAssertEqual(presenter.lastResponse?.cards.count, 2)

        await sut.search(request: .init(query: "уникальный"))
        XCTAssertEqual(presenter.lastResponse?.cards.count, 1)
        XCTAssertEqual(presenter.lastResponse?.cards.first?.id, "7-sounds")
    }

    func test_search_emptyQuery_returnsAllForAge() async {
        let (sut, presenter, _) = makeSUT()
        await sut.load(request: .init(initialAge: .seven, query: "уникальный"))
        XCTAssertEqual(presenter.lastResponse?.cards.count, 1)

        await sut.search(request: .init(query: ""))
        XCTAssertEqual(presenter.lastResponse?.cards.count, 2)
    }
}
