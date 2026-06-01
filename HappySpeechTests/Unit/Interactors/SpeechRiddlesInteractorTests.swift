@testable import HappySpeech
import XCTest

// MARK: - SpeechRiddlesInteractorTests
//
// SpeechRiddlesInteractor загружает загадки из словаря через worker и
// фиксирует результаты в AdaptivePlannerService. Тесты используют
// детерминированный mock-worker.

@MainActor
final class SpeechRiddlesInteractorTests: XCTestCase {

    private final class MockWorker: SpeechRiddlesWorkerProtocol {
        let riddles: [SpeechRiddlesModels.Riddle]
        var lastChildId: String?
        init(riddles: [SpeechRiddlesModels.Riddle]) { self.riddles = riddles }
        func buildRiddles(childId: String) async -> [SpeechRiddlesModels.Riddle] {
            lastChildId = childId
            return riddles
        }
    }

    private func makeRiddle(id: String) -> SpeechRiddlesModels.Riddle {
        SpeechRiddlesModels.Riddle(
            id: id,
            prompt: "Что начинается на «С»?",
            targetLetter: "С",
            options: [
                SpeechRiddlesModels.Option(id: "ok", asset: "word_dog", label: "Слон", startsWith: "С"),
                SpeechRiddlesModels.Option(id: "no", asset: nil, label: "Банан", startsWith: "Б")
            ],
            correctOptionId: "ok"
        )
    }

    private func makeSUT(childId: String = "child-1") -> (SpeechRiddlesInteractor, MockWorker) {
        let worker = MockWorker(riddles: [makeRiddle(id: "q1"), makeRiddle(id: "q2")])
        let sut = SpeechRiddlesInteractor(childId: childId, worker: worker)
        return (sut, worker)
    }

    func test_init_storesChildId() {
        let (sut, _) = makeSUT(childId: "kid-9")
        XCTAssertEqual(sut.childId, "kid-9")
    }

    func test_load_withoutWorker_marksLoadedEmpty() async {
        let sut = SpeechRiddlesInteractor(childId: "c")
        await sut.load()
        XCTAssertTrue(sut.state.isLoaded)
        XCTAssertTrue(sut.state.isEmpty)
    }

    func test_load_populatesRiddles() async {
        let (sut, worker) = makeSUT()
        await sut.load()
        XCTAssertEqual(sut.state.riddles.count, 2)
        XCTAssertEqual(sut.state.current?.id, "q1")
        XCTAssertEqual(worker.lastChildId, "child-1")
    }

    func test_answer_correct_incrementsScore() async {
        let (sut, _) = makeSUT()
        await sut.load()
        sut.answer("ok")
        XCTAssertEqual(sut.state.score, 1)
        XCTAssertEqual(sut.state.feedback, .correct)
    }

    func test_answer_correct_autoAdvances() async {
        let (sut, _) = makeSUT()
        await sut.load()
        sut.answer("ok")
        XCTAssertEqual(sut.state.currentIndex, 0)
        try? await Task.sleep(for: .milliseconds(900))
        XCTAssertEqual(sut.state.currentIndex, 1)
    }

    func test_answer_wrong_setsFeedbackWithoutScore() async {
        let (sut, _) = makeSUT()
        await sut.load()
        sut.answer("no")
        XCTAssertEqual(sut.state.feedback, .wrong("no"))
        XCTAssertEqual(sut.state.score, 0)
    }

    func test_advance_pastLast_marksComplete() async {
        let (sut, _) = makeSUT()
        await sut.load()
        for _ in 0..<sut.state.riddles.count { sut.advance() }
        XCTAssertTrue(sut.state.isComplete)
        XCTAssertNil(sut.state.current)
    }

    func test_progress_advancesProportionally() async {
        let (sut, _) = makeSUT()
        await sut.load()
        sut.advance()
        XCTAssertEqual(sut.state.progress, 1.0 / 2.0, accuracy: 0.0001)
    }

    func test_reset_keepsRiddlesResetsProgress() async {
        let (sut, _) = makeSUT()
        await sut.load()
        sut.answer("ok")
        sut.advance()
        sut.reset()
        XCTAssertEqual(sut.state.currentIndex, 0)
        XCTAssertEqual(sut.state.score, 0)
        XCTAssertEqual(sut.state.riddles.count, 2)
    }
}
