@testable import HappySpeech
import XCTest

// MARK: - Spy DisplayLogic

@MainActor
private final class SpyPhonemicDisplay: PhonemicListeningDisplayLogic, @unchecked Sendable {
    var startVM: PhonemicListeningModels.Start.ViewModel?
    var answerVM: PhonemicListeningModels.Answer.ViewModel?

    func displayStart(viewModel: PhonemicListeningModels.Start.ViewModel) async {
        startVM = viewModel
    }
    func displayAnswer(viewModel: PhonemicListeningModels.Answer.ViewModel) async {
        answerVM = viewModel
    }
}

// MARK: - Helpers

private let positionWord = PhonemicWord(
    id: "w", text: "сок", targetSound: "С",
    position: .start, sounds: ["с", "о", "к"]
)
private let countWord = PhonemicWord(
    id: "w2", text: "роза", targetSound: "Р",
    position: .start, sounds: ["р", "о", "з", "а"]
)
private let synthWord = PhonemicWord(
    id: "w3", text: "кот", targetSound: "К",
    position: .start, sounds: ["к", "о", "т"]
)

// MARK: - Presenter Tests

@MainActor
final class PhonemicListeningPresenterTests: XCTestCase {

    private func makeSUT() -> (PhonemicListeningPresenter, SpyPhonemicDisplay) {
        let display = SpyPhonemicDisplay()
        let sut = PhonemicListeningPresenter(displayLogic: display)
        return (sut, display)
    }

    func test_presentStart_buildsViewModelWithFirstRound() async {
        let (sut, display) = makeSUT()
        let rounds = [
            PhonemicRound(id: "r1", operation: .position, word: positionWord),
            PhonemicRound(id: "r2", operation: .count, word: countWord)
        ]
        await sut.presentStart(response: .init(rounds: rounds))
        XCTAssertNotNil(display.startVM)
        XCTAssertEqual(display.startVM?.totalRounds, 2)
        XCTAssertEqual(display.startVM?.firstRound.word, "сок")
        XCTAssertFalse(display.startVM?.firstRound.prompt.isEmpty ?? true)
    }

    func test_positionRound_hasThreeOptions() async {
        let (sut, display) = makeSUT()
        let round = PhonemicRound(id: "r1", operation: .position, word: positionWord)
        await sut.presentStart(response: .init(rounds: [round]))
        XCTAssertEqual(display.startVM?.firstRound.options.count, 3)
    }

    func test_countRound_correctOptionIsSoundCount() async {
        let (sut, display) = makeSUT()
        let round = PhonemicRound(id: "r1", operation: .count, word: countWord)
        await sut.presentStart(response: .init(rounds: [round]))
        // Индекс правильного варианта (1) должен показывать кол-во звуков (4).
        let options = display.startVM?.firstRound.options ?? []
        XCTAssertEqual(options.count, 3)
        XCTAssertEqual(options[1].label, "\(countWord.soundCount)")
    }

    func test_synthesisRound_correctWordIsFirstOption() async {
        let (sut, display) = makeSUT()
        let round = PhonemicRound(id: "r1", operation: .synthesis, word: synthWord)
        await sut.presentStart(response: .init(rounds: [round]))
        let options = display.startVM?.firstRound.options ?? []
        XCTAssertFalse(options.isEmpty)
        XCTAssertEqual(options.first?.label, synthWord.text)
    }

    func test_presentAnswer_correct_setsFeedback() async {
        let (sut, display) = makeSUT()
        let next = PhonemicRound(id: "r2", operation: .count, word: countWord)
        await sut.presentAnswer(response: .init(
            wasCorrect: true,
            isFinished: false,
            nextRound: next,
            nextRoundIndex: 1,
            correctCount: 1,
            totalRounds: 2
        ))
        XCTAssertEqual(display.answerVM?.wasCorrect, true)
        XCTAssertFalse(display.answerVM?.feedbackText.isEmpty ?? true)
        XCTAssertNotNil(display.answerVM?.nextRound)
        XCTAssertNil(display.answerVM?.summary)
    }

    func test_presentAnswer_finished_buildsSummary() async {
        let (sut, display) = makeSUT()
        await sut.presentAnswer(response: .init(
            wasCorrect: true,
            isFinished: true,
            nextRound: nil,
            nextRoundIndex: nil,
            correctCount: 9,
            totalRounds: 9
        ))
        XCTAssertEqual(display.answerVM?.isFinished, true)
        XCTAssertNotNil(display.answerVM?.summary)
        XCTAssertEqual(display.answerVM?.summary?.accuracyFraction, 1.0)
        XCTAssertFalse(display.answerVM?.summary?.encouragement.isEmpty ?? true)
    }

    func test_presentAnswer_finishedLowAccuracy_stillEncourages() async {
        let (sut, display) = makeSUT()
        await sut.presentAnswer(response: .init(
            wasCorrect: false,
            isFinished: true,
            nextRound: nil,
            nextRoundIndex: nil,
            correctCount: 1,
            totalRounds: 9
        ))
        XCTAssertFalse(display.answerVM?.summary?.encouragement.isEmpty ?? true)
    }
}
