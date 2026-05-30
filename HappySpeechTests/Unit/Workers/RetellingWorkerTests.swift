@testable import HappySpeech
import XCTest

// MARK: - RetellingWorkerTests
//
// Фаза E, Волна 8. Покрывает RetellingWorker.pickStory: история берётся из
// корпуса независимо от целевых звуков; чтение профиля не блокирует выдачу
// (сбой профиля → история всё равно отдаётся). Также — чистая логика корпуса
// (story(id:), randomStory непустой) и модели (RetellingStory.fullText,
// SemanticLinkKind.symbolName).

@MainActor
final class RetellingWorkerTests: XCTestCase {

    private func child(id: String = "c-1") -> ChildProfileDTO {
        ChildProfileDTO(id: id, name: "Тест", age: 7, targetSounds: ["Р"], parentId: "p-1")
    }

    private func makeSUT(children: [ChildProfileDTO]) -> RetellingWorker {
        RetellingWorker(childRepository: MockChildRepository(children: children))
    }

    // MARK: - pickStory

    func test_pickStory_returnsNonEmptyStory() async {
        let sut = makeSUT(children: [child()])
        let response = await sut.pickStory(childId: "c-1")
        XCTAssertFalse(response.story.frames.isEmpty,
                       "История содержит хотя бы один кадр")
        XCTAssertFalse(response.story.id.isEmpty)
    }

    func test_pickStory_servedEvenWhenChildMissing() async {
        // Сбой чтения профиля не должен блокировать выдачу истории.
        let sut = makeSUT(children: [])
        let response = await sut.pickStory(childId: "missing")
        XCTAssertFalse(response.story.frames.isEmpty)
    }

    func test_pickStory_storyComesFromCorpus() async {
        let sut = makeSUT(children: [child()])
        let response = await sut.pickStory(childId: "c-1")
        // Возвращённая история должна находиться в корпусе по своему id.
        XCTAssertNotNil(RetellingCorpus.story(id: response.story.id),
                        "Выданная история принадлежит корпусу")
    }

    // MARK: - RetellingCorpus

    func test_corpus_randomStory_alwaysReturnsValidStory() {
        for _ in 0..<10 {
            let story = RetellingCorpus.randomStory()
            XCTAssertFalse(story.frames.isEmpty)
        }
    }

    func test_corpus_story_unknownIdReturnsNil() {
        XCTAssertNil(RetellingCorpus.story(id: "no-such-story"))
    }

    func test_corpus_story_knownIdRoundTrips() {
        guard let any = RetellingCorpus.stories.first else {
            return XCTFail("Корпус историй пуст")
        }
        XCTAssertEqual(RetellingCorpus.story(id: any.id)?.id, any.id)
    }

    func test_corpus_storiesHaveUniqueIds() {
        let ids = RetellingCorpus.stories.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    // MARK: - RetellingStory.fullText (pure model logic)

    func test_story_fullText_joinsSentencesWithSpace() {
        let story = RetellingStory(
            id: "s", title: "T",
            frames: [
                .init(id: "1", sentence: "Жил кот.", link: .hero, symbolName: "cat.fill"),
                .init(id: "2", sentence: "Он гулял.", link: .place, symbolName: "tree.fill")
            ]
        )
        XCTAssertEqual(story.fullText, "Жил кот. Он гулял.")
    }

    func test_story_fullText_singleFrame() {
        let story = RetellingStory(
            id: "s", title: "T",
            frames: [.init(id: "1", sentence: "Одно.", link: .hero, symbolName: "x")]
        )
        XCTAssertEqual(story.fullText, "Одно.")
    }

    // MARK: - SemanticLinkKind (pure)

    func test_semanticLinkKind_symbolNamesAreDistinct() {
        let symbols = SemanticLinkKind.allCases.map(\.symbolName)
        XCTAssertEqual(symbols.count, Set(symbols).count,
                       "У каждого смыслового звена свой символ")
    }
}
