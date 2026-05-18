@testable import HappySpeech
import XCTest

// MARK: - Spy DisplayLogic

@MainActor
private final class SpyTrafficLightDisplay: SoundTrafficLightDisplayLogic, @unchecked Sendable {
    var startVM: SoundTrafficLightModels.Start.ViewModel?
    var sortVM: SoundTrafficLightModels.Sort.ViewModel?

    func displayStart(viewModel: SoundTrafficLightModels.Start.ViewModel) async {
        startVM = viewModel
    }
    func displaySort(viewModel: SoundTrafficLightModels.Sort.ViewModel) async {
        sortVM = viewModel
    }
}

// MARK: - Presenter Tests

@MainActor
final class SoundTrafficLightPresenterTests: XCTestCase {

    private func makeSUT() -> (SoundTrafficLightPresenter, SpyTrafficLightDisplay) {
        let display = SpyTrafficLightDisplay()
        let sut = SoundTrafficLightPresenter(displayLogic: display)
        return (sut, display)
    }

    private let pair = DifferentiationPair(
        id: "p", soundA: "С", soundB: "Ш",
        wordsA: ["сок"], wordsB: ["шар"]
    )

    private let rounds: [TrafficLightRound] = [
        .init(id: "r1", word: "сок", belongsToA: true),
        .init(id: "r2", word: "шар", belongsToA: false)
    ]

    func test_presentStart_buildsViewModelWithFirstRound() async {
        let (sut, display) = makeSUT()
        await sut.presentStart(response: .init(pair: pair, rounds: rounds))
        XCTAssertNotNil(display.startVM)
        XCTAssertEqual(display.startVM?.totalRounds, 2)
        XCTAssertEqual(display.startVM?.firstRound.word, "сок")
    }

    func test_presentStart_garageLabelsContainSounds() async {
        let (sut, display) = makeSUT()
        await sut.presentStart(response: .init(pair: pair, rounds: rounds))
        XCTAssertTrue(display.startVM?.garageALabel.contains("С") ?? false)
        XCTAssertTrue(display.startVM?.garageBLabel.contains("Ш") ?? false)
    }

    func test_presentSort_correct_setsCorrectFeedback() async {
        let (sut, display) = makeSUT()
        await sut.presentSort(response: .init(
            wasCorrect: true,
            isFinished: false,
            nextRound: rounds[1],
            nextRoundIndex: 1,
            correctCount: 1,
            totalRounds: 2
        ))
        XCTAssertEqual(display.sortVM?.wasCorrect, true)
        XCTAssertFalse(display.sortVM?.feedbackText.isEmpty ?? true)
        XCTAssertNotNil(display.sortVM?.nextRound)
        XCTAssertNil(display.sortVM?.summary)
    }

    func test_presentSort_finished_buildsSummary() async {
        let (sut, display) = makeSUT()
        await sut.presentSort(response: .init(
            wasCorrect: true,
            isFinished: true,
            nextRound: nil,
            nextRoundIndex: nil,
            correctCount: 2,
            totalRounds: 2
        ))
        XCTAssertEqual(display.sortVM?.isFinished, true)
        XCTAssertNotNil(display.sortVM?.summary)
        XCTAssertEqual(display.sortVM?.summary?.correctCount, 2)
        XCTAssertEqual(display.sortVM?.summary?.accuracyFraction, 1.0)
    }

    func test_presentSort_finishedLowAccuracy_stillEncourages() async {
        let (sut, display) = makeSUT()
        await sut.presentSort(response: .init(
            wasCorrect: false,
            isFinished: true,
            nextRound: nil,
            nextRoundIndex: nil,
            correctCount: 1,
            totalRounds: 8
        ))
        XCTAssertFalse(display.sortVM?.summary?.encouragement.isEmpty ?? true)
    }

    func test_presentSort_nextRoundIndex_reflectedInProgress() async {
        let (sut, display) = makeSUT()
        await sut.presentSort(response: .init(
            wasCorrect: true,
            isFinished: false,
            nextRound: rounds[1],
            nextRoundIndex: 1,
            correctCount: 1,
            totalRounds: 2
        ))
        // Round index 1 (0-based) -> "слово 2 из 2"
        XCTAssertTrue(display.sortVM?.nextRound?.progressLabel.contains("2") ?? false)
    }
}
