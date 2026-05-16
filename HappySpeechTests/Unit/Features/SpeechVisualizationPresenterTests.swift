import XCTest
import SwiftUI
@testable import HappySpeech

// MARK: - SpeechVisualizationPresenterTests
//
// Phase 2.6 batch 3 — покрытие SpeechVisualizationPresenter (0% → цель ≥90%).

@MainActor
final class SpeechVisualizationPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: SpeechVisualizationDisplayLogic {
        var loadVM: SpeechVisualizationModels.Load.ViewModel?
        var setModeVM: SpeechVisualizationModels.SetMode.ViewModel?
        var scoreVM: SpeechVisualizationModels.Score.ViewModel?

        func displayLoad(viewModel: SpeechVisualizationModels.Load.ViewModel) async { loadVM = viewModel }
        func displaySetMode(viewModel: SpeechVisualizationModels.SetMode.ViewModel) async { setModeVM = viewModel }
        func displayScore(viewModel: SpeechVisualizationModels.Score.ViewModel) async { scoreVM = viewModel }
    }

    private func makeSUT() -> (SpeechVisualizationPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let sut = SpeechVisualizationPresenter(displayLogic: spy)
        return (sut, spy)
    }

    private func makeSyllable(id: String, text: String, duration: Double = 0.5) -> KaraokeSyllable {
        KaraokeSyllable(id: id, text: text, durationSeconds: duration, startOffset: 0)
    }

    // MARK: - presentLoad

    func test_presentLoad_wordDisplay_matches() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(word: "солнце", syllables: [], totalDuration: 2.0))
        XCTAssertNotNil(spy.loadVM)
        XCTAssertEqual(spy.loadVM?.wordDisplay, "солнце")
    }

    func test_presentLoad_titleNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(word: "рыба", syllables: [], totalDuration: 1.5))
        XCTAssertFalse(spy.loadVM?.title.isEmpty ?? true)
    }

    func test_presentLoad_syllables_mappedCorrectly() async {
        let (sut, spy) = makeSUT()
        let syllables = [makeSyllable(id: "s1", text: "солн"), makeSyllable(id: "s2", text: "це")]
        await sut.presentLoad(response: .init(word: "солнце", syllables: syllables, totalDuration: 1.0))
        XCTAssertEqual(spy.loadVM?.syllables.count, 2)
        XCTAssertEqual(spy.loadVM?.syllables.first?.text, "солн")
        XCTAssertEqual(spy.loadVM?.syllables.first?.state, .idle)
    }

    func test_presentLoad_syllable_accessibilityLabelNotEmpty() async {
        let (sut, spy) = makeSUT()
        let syllables = [makeSyllable(id: "s1", text: "ры")]
        await sut.presentLoad(response: .init(word: "рыба", syllables: syllables, totalDuration: 1.0))
        XCTAssertFalse(spy.loadVM?.syllables.first?.accessibilityLabel.isEmpty ?? true)
    }

    func test_presentLoad_totalDurationLabel_notEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(word: "дом", syllables: [], totalDuration: 3.5))
        XCTAssertFalse(spy.loadVM?.totalDurationLabel.isEmpty ?? true)
    }

    // MARK: - presentSetMode

    func test_presentSetMode_listen_instructionAndCtaNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentSetMode(mode: .listen)
        XCTAssertNotNil(spy.setModeVM)
        XCTAssertEqual(spy.setModeVM?.mode, .listen)
        XCTAssertFalse(spy.setModeVM?.instructionText.isEmpty ?? true)
        XCTAssertFalse(spy.setModeVM?.primaryButtonTitle.isEmpty ?? true)
    }

    func test_presentSetMode_practice_instructionAndCtaNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentSetMode(mode: .practice)
        XCTAssertEqual(spy.setModeVM?.mode, .practice)
        XCTAssertFalse(spy.setModeVM?.instructionText.isEmpty ?? true)
        XCTAssertFalse(spy.setModeVM?.primaryButtonTitle.isEmpty ?? true)
    }

    func test_presentSetMode_listenAndPractice_differentInstructions() async {
        let (sut, spy) = makeSUT()
        await sut.presentSetMode(mode: .listen)
        let listenInstruction = spy.setModeVM?.instructionText

        await sut.presentSetMode(mode: .practice)
        let practiceInstruction = spy.setModeVM?.instructionText

        XCTAssertNotEqual(listenInstruction, practiceInstruction)
    }

    // MARK: - presentScore

    func test_presentScore_highAccuracy_syllableStateCorrect() async {
        let (sut, spy) = makeSUT()
        let syllables = [makeSyllable(id: "s1", text: "со")]
        await sut.presentScore(
            response: .init(perSyllableAccuracy: [0.9], overallAccuracy: 0.9),
            syllables: syllables
        )
        XCTAssertNotNil(spy.scoreVM)
        XCTAssertEqual(spy.scoreVM?.updatedSyllables.first?.state, .correct)
        XCTAssertTrue(spy.scoreVM?.confettiBurst == true)
    }

    func test_presentScore_warningAccuracy_syllableStateWarning() async {
        let (sut, spy) = makeSUT()
        let syllables = [makeSyllable(id: "s1", text: "со")]
        await sut.presentScore(
            response: .init(perSyllableAccuracy: [0.65], overallAccuracy: 0.65),
            syllables: syllables
        )
        XCTAssertEqual(spy.scoreVM?.updatedSyllables.first?.state, .warning)
        XCTAssertFalse(spy.scoreVM?.confettiBurst ?? true)
    }

    func test_presentScore_lowAccuracy_syllableStateIncorrect() async {
        let (sut, spy) = makeSUT()
        let syllables = [makeSyllable(id: "s1", text: "ба")]
        await sut.presentScore(
            response: .init(perSyllableAccuracy: [0.3], overallAccuracy: 0.3),
            syllables: syllables
        )
        XCTAssertEqual(spy.scoreVM?.updatedSyllables.first?.state, .incorrect)
        XCTAssertFalse(spy.scoreVM?.confettiBurst ?? true)
    }

    func test_presentScore_exactlyAt08_isCorrect() async {
        let (sut, spy) = makeSUT()
        let syllables = [makeSyllable(id: "s1", text: "со")]
        await sut.presentScore(
            response: .init(perSyllableAccuracy: [0.8], overallAccuracy: 0.8),
            syllables: syllables
        )
        XCTAssertEqual(spy.scoreVM?.updatedSyllables.first?.state, .correct)
        XCTAssertTrue(spy.scoreVM?.confettiBurst == true)
    }

    func test_presentScore_exactlyAt05_isWarning() async {
        let (sut, spy) = makeSUT()
        let syllables = [makeSyllable(id: "s1", text: "со")]
        await sut.presentScore(
            response: .init(perSyllableAccuracy: [0.5], overallAccuracy: 0.5),
            syllables: syllables
        )
        XCTAssertEqual(spy.scoreVM?.updatedSyllables.first?.state, .warning)
    }

    func test_presentScore_summaryTextNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentScore(
            response: .init(perSyllableAccuracy: [], overallAccuracy: 0.75),
            syllables: []
        )
        XCTAssertFalse(spy.scoreVM?.summaryText.isEmpty ?? true)
    }

    func test_presentScore_multipleSyllables_allMapped() async {
        let (sut, spy) = makeSUT()
        let syllables = [
            makeSyllable(id: "s1", text: "солн"),
            makeSyllable(id: "s2", text: "це")
        ]
        await sut.presentScore(
            response: .init(perSyllableAccuracy: [0.9, 0.4], overallAccuracy: 0.65),
            syllables: syllables
        )
        let states = spy.scoreVM?.updatedSyllables.map(\.state) ?? []
        XCTAssertEqual(states, [.correct, .incorrect])
    }

    func test_presentScore_overallHigh_confettiTrue() async {
        let (sut, spy) = makeSUT()
        await sut.presentScore(
            response: .init(perSyllableAccuracy: [], overallAccuracy: 0.85),
            syllables: []
        )
        XCTAssertTrue(spy.scoreVM?.confettiBurst == true)
    }

    func test_presentScore_overallLow_confettiFalse() async {
        let (sut, spy) = makeSUT()
        await sut.presentScore(
            response: .init(perSyllableAccuracy: [], overallAccuracy: 0.5),
            syllables: []
        )
        XCTAssertFalse(spy.scoreVM?.confettiBurst ?? true)
    }
}
