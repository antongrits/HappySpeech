@testable import HappySpeech
import XCTest

// MARK: - PhonemeFamilyMatcherInteractorTests
//
// PhonemeFamilyMatcherInteractor загружает слова из словаря через worker и
// фиксирует результат сортировки. Тесты используют детерминированный
// mock-worker.

@MainActor
final class PhonemeFamilyMatcherInteractorTests: XCTestCase {

    private final class MockWorker: PhonemeFamilyMatcherWorkerProtocol {
        let words: [PhonemeFamilyMatcherModels.Word]
        init(words: [PhonemeFamilyMatcherModels.Word]) { self.words = words }
        func buildWords(childId: String) async -> [PhonemeFamilyMatcherModels.Word] { words }
    }

    private func sampleWords() -> [PhonemeFamilyMatcherModels.Word] {
        [
            .init(id: "w1", text: "Сова", family: .whistling, assignedFamily: nil),
            .init(id: "w2", text: "Шапка", family: .hissing, assignedFamily: nil),
            .init(id: "w3", text: "Рыба", family: .sonorant, assignedFamily: nil),
            .init(id: "w4", text: "Кот", family: .velar, assignedFamily: nil)
        ]
    }

    private func makeSUT(childId: String = "child-1") -> PhonemeFamilyMatcherInteractor {
        PhonemeFamilyMatcherInteractor(
            childId: childId,
            worker: MockWorker(words: sampleWords())
        )
    }

    func test_init_storesChildId() {
        let sut = PhonemeFamilyMatcherInteractor(childId: "kid-3")
        XCTAssertEqual(sut.childId, "kid-3")
    }

    func test_load_withoutWorker_marksLoadedEmpty() async {
        let sut = PhonemeFamilyMatcherInteractor(childId: "c")
        await sut.load()
        XCTAssertTrue(sut.state.isLoaded)
        XCTAssertTrue(sut.state.isEmpty)
    }

    func test_load_populatesWords() async {
        let sut = makeSUT()
        await sut.load()
        XCTAssertEqual(sut.state.words.count, 4)
        XCTAssertEqual(sut.state.matchedCount, 0)
    }

    func test_assign_correct_incrementsMatched() async {
        let sut = makeSUT()
        await sut.load()
        sut.assign("w1", to: .whistling)
        XCTAssertEqual(sut.state.matchedCount, 1)
    }

    func test_assign_wrong_doesNotCountAsMatched() async {
        let sut = makeSUT()
        await sut.load()
        sut.assign("w1", to: .velar)
        XCTAssertEqual(sut.state.matchedCount, 0)
        XCTAssertEqual(sut.state.words.first { $0.id == "w1" }?.assignedFamily, .velar)
    }

    func test_assign_unknownId_noop() async {
        let sut = makeSUT()
        await sut.load()
        sut.assign("nope", to: .whistling)
        XCTAssertEqual(sut.state.matchedCount, 0)
    }

    func test_allAssigned_whenEveryWordTagged() async {
        let sut = makeSUT()
        await sut.load()
        sut.assign("w1", to: .whistling)
        sut.assign("w2", to: .hissing)
        sut.assign("w3", to: .sonorant)
        sut.assign("w4", to: .velar)
        XCTAssertTrue(sut.state.allAssigned)
        XCTAssertEqual(sut.state.matchedCount, 4)
    }

    func test_reset_clearsAssignments() async {
        let sut = makeSUT()
        await sut.load()
        sut.assign("w1", to: .whistling)
        sut.reset()
        XCTAssertEqual(sut.state.matchedCount, 0)
        XCTAssertTrue(sut.state.words.allSatisfy { $0.assignedFamily == nil })
    }
}
