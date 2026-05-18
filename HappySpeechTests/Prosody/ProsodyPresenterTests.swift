@testable import HappySpeech
import XCTest

// MARK: - Spy DisplayLogic

@MainActor
private final class SpyProsodyDisplay: ProsodyDisplayLogic, @unchecked Sendable {
    var startVM: ProsodyModels.Start.ViewModel?
    var answerVM: ProsodyModels.Answer.ViewModel?

    func displayStart(viewModel: ProsodyModels.Start.ViewModel) async {
        startVM = viewModel
    }
    func displayAnswer(viewModel: ProsodyModels.Answer.ViewModel) async {
        answerVM = viewModel
    }
}

// MARK: - Helpers

private let declPhrase = ProsodyPhrase(
    id: "p1", text: "Кошка спит.", intonation: .declarative, theme: "T"
)
private let interPhrase = ProsodyPhrase(
    id: "p2", text: "Кто там?", intonation: .interrogative, theme: "T"
)

// MARK: - Presenter Tests

@MainActor
final class ProsodyPresenterTests: XCTestCase {

    private func makeSUT() -> (ProsodyPresenter, SpyProsodyDisplay) {
        let display = SpyProsodyDisplay()
        let sut = ProsodyPresenter(displayLogic: display)
        return (sut, display)
    }

    func test_presentStart_buildsViewModel() async {
        let (sut, display) = makeSUT()
        let rounds = [
            ProsodyRound(id: "r1", stage: .discriminate, phrase: declPhrase),
            ProsodyRound(id: "r2", stage: .imitate, phrase: interPhrase)
        ]
        await sut.presentStart(response: .init(rounds: rounds))
        XCTAssertNotNil(display.startVM)
        XCTAssertEqual(display.startVM?.totalRounds, 2)
        XCTAssertEqual(display.startVM?.firstRound.phraseText, "Кошка спит.")
        XCTAssertFalse(display.startVM?.firstRound.prompt.isEmpty ?? true)
    }

    func test_discriminateRound_hasThreeOptions() async {
        let (sut, display) = makeSUT()
        let round = ProsodyRound(id: "r1", stage: .discriminate, phrase: declPhrase)
        await sut.presentStart(response: .init(rounds: [round]))
        XCTAssertEqual(display.startVM?.firstRound.options.count, 3)
        XCTAssertEqual(display.startVM?.firstRound.needsVoice, false)
    }

    func test_imitateRound_needsVoiceAndNoOptions() async {
        let (sut, display) = makeSUT()
        let round = ProsodyRound(id: "r1", stage: .imitate, phrase: interPhrase)
        await sut.presentStart(response: .init(rounds: [round]))
        XCTAssertTrue(display.startVM?.firstRound.options.isEmpty ?? false)
        XCTAssertEqual(display.startVM?.firstRound.needsVoice, true)
    }

    func test_presentAnswer_correct_setsFeedback() async {
        let (sut, display) = makeSUT()
        let next = ProsodyRound(id: "r2", stage: .imitate, phrase: interPhrase)
        await sut.presentAnswer(response: .init(
            wasCorrect: true,
            isFinished: false,
            nextRound: next,
            nextRoundIndex: 1,
            correctCount: 1,
            totalRounds: 3
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
}
