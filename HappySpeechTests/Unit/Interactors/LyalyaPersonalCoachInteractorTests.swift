@testable import HappySpeech
import XCTest

// MARK: - LyalyaPersonalCoachInteractorTests
//
// LyalyaPersonalCoachInteractor персонализирует викторину через worker и
// фиксирует результаты. Тесты используют детерминированный mock-worker.

@MainActor
final class LyalyaPersonalCoachInteractorTests: XCTestCase {

    private final class MockWorker: LyalyaPersonalCoachWorkerProtocol {
        let rounds: [LyalyaPersonalCoachModels.Round]
        var lastChildId: String?
        init(rounds: [LyalyaPersonalCoachModels.Round]) { self.rounds = rounds }
        func buildRounds(childId: String) async -> [LyalyaPersonalCoachModels.Round] {
            lastChildId = childId
            return rounds
        }
    }

    private func sampleRounds() -> [LyalyaPersonalCoachModels.Round] {
        [
            .init(id: 1, question: "Какой первый звук в слове «сова»?", options: ["С", "О", "В", "А"], correctIndex: 0),
            .init(id: 2, question: "Какой первый звук в слове «рыба»?", options: ["Р", "Ы", "Б", "А"], correctIndex: 0)
        ]
    }

    private func makeSUT(childId: String = "child-1") -> (LyalyaPersonalCoachInteractor, MockWorker) {
        let worker = MockWorker(rounds: sampleRounds())
        return (LyalyaPersonalCoachInteractor(childId: childId, worker: worker), worker)
    }

    func test_load_populatesRounds() async {
        let (sut, worker) = makeSUT()
        await sut.load()
        XCTAssertTrue(sut.isLoaded)
        XCTAssertEqual(sut.rounds.count, 2)
        XCTAssertEqual(sut.current?.id, 1)
        XCTAssertEqual(worker.lastChildId, "child-1")
    }

    func test_load_withoutWorker_marksEmpty() async {
        let sut = LyalyaPersonalCoachInteractor(childId: "c")
        await sut.load()
        XCTAssertTrue(sut.isLoaded)
        XCTAssertTrue(sut.isEmpty)
    }

    func test_answer_correct_incrementsAndReacts() async {
        let (sut, _) = makeSUT()
        await sut.load()
        sut.answer(0)
        XCTAssertEqual(sut.reaction, .correct)
        XCTAssertEqual(sut.correctCount, 1)
    }

    func test_answer_wrong_reactsTryAgain() async {
        let (sut, _) = makeSUT()
        await sut.load()
        sut.answer(1)
        XCTAssertEqual(sut.reaction, .tryAgain)
        XCTAssertEqual(sut.correctCount, 0)
    }

    func test_next_advancesAndClearsReaction() async {
        let (sut, _) = makeSUT()
        await sut.load()
        sut.answer(0)
        sut.next()
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(sut.reaction, .none)
    }

    func test_playThrough_marksFinished() async {
        let (sut, _) = makeSUT()
        await sut.load()
        for _ in 0..<sut.rounds.count {
            sut.answer(0)
            sut.next()
        }
        XCTAssertTrue(sut.isFinished)
        XCTAssertNil(sut.current)
        XCTAssertEqual(sut.correctCount, 2)
    }

    func test_restart_reloads() async {
        let (sut, _) = makeSUT()
        await sut.load()
        sut.answer(0); sut.next()
        await sut.restart()
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
    }

    // MARK: - Worker pure

    func test_worker_makeFirstSoundRound_correctIndexPointsToFirstLetter() {
        let round = LyalyaPersonalCoachWorker.makeFirstSoundRound(word: "Сова", id: 1)
        XCTAssertNotNil(round)
        XCTAssertEqual(round?.options[round!.correctIndex], "С")
    }

    func test_worker_makeFirstSoundRound_shortWordReturnsNil() {
        XCTAssertNil(LyalyaPersonalCoachWorker.makeFirstSoundRound(word: "Я", id: 1))
    }
}
