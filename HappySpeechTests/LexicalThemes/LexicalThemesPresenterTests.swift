@testable import HappySpeech
import XCTest

// MARK: - Spy DisplayLogic

@MainActor
private final class SpyLexicalDisplay: LexicalThemesDisplayLogic, @unchecked Sendable {
    var themesVM: LexicalThemesModels.LoadThemes.ViewModel?
    var startVM: LexicalThemesModels.StartTheme.ViewModel?
    var answerVM: LexicalThemesModels.Answer.ViewModel?

    func displayThemes(viewModel: LexicalThemesModels.LoadThemes.ViewModel) async {
        themesVM = viewModel
    }
    func displayThemeStart(viewModel: LexicalThemesModels.StartTheme.ViewModel) async {
        startVM = viewModel
    }
    func displayAnswer(viewModel: LexicalThemesModels.Answer.ViewModel) async {
        answerVM = viewModel
    }
}

// MARK: - Helpers

private let veggieWord = LexicalWord(
    id: "veg-1", text: "морковь", action: "растёт", attribute: "оранжевая"
)

// MARK: - Presenter Tests

@MainActor
final class LexicalThemesPresenterTests: XCTestCase {

    private func makeSUT() -> (LexicalThemesPresenter, SpyLexicalDisplay) {
        let display = SpyLexicalDisplay()
        let sut = LexicalThemesPresenter(displayLogic: display)
        return (sut, display)
    }

    func test_presentThemes_buildsCards() async {
        let (sut, display) = makeSUT()
        await sut.presentThemes(response: .init(
            themes: LexicalThemesCorpus.themes,
            masteredThemeIds: ["vegetables"]
        ))
        XCTAssertEqual(display.themesVM?.themes.count, LexicalThemesCorpus.themes.count)
        let veggie = display.themesVM?.themes.first { $0.id == "vegetables" }
        XCTAssertEqual(veggie?.isMastered, true)
    }

    func test_presentThemeStart_buildsRoundWithOptions() async {
        let (sut, display) = makeSUT()
        let round = LexicalRound(
            id: "r1", kind: .naming, word: veggieWord, themeId: "vegetables"
        )
        await sut.presentThemeStart(response: .init(
            theme: LexicalThemesCorpus.vegetables,
            rounds: [round]
        ))
        XCTAssertEqual(display.startVM?.totalRounds, 1)
        XCTAssertEqual(display.startVM?.firstRound.options.count, 3)
        // Индекс 0 — правильный вариант.
        XCTAssertEqual(display.startVM?.firstRound.options.first?.id, 0)
    }

    func test_namingRound_correctOptionIsTargetWord() async {
        let (sut, display) = makeSUT()
        let round = LexicalRound(
            id: "r1", kind: .naming, word: veggieWord, themeId: "vegetables"
        )
        await sut.presentThemeStart(response: .init(
            theme: LexicalThemesCorpus.vegetables,
            rounds: [round]
        ))
        XCTAssertEqual(display.startVM?.firstRound.options.first?.label, "морковь")
    }

    func test_actionRound_correctOptionIsAction() async {
        let (sut, display) = makeSUT()
        let round = LexicalRound(
            id: "r1", kind: .action, word: veggieWord, themeId: "vegetables"
        )
        await sut.presentThemeStart(response: .init(
            theme: LexicalThemesCorpus.vegetables,
            rounds: [round]
        ))
        XCTAssertEqual(display.startVM?.firstRound.options.first?.label, "растёт")
    }

    func test_presentAnswer_finishedHighAccuracy_marksMastered() async {
        let (sut, display) = makeSUT()
        await sut.presentAnswer(response: .init(
            wasCorrect: true,
            isFinished: true,
            nextRound: nil,
            nextRoundIndex: nil,
            correctCount: 8,
            totalRounds: 8
        ))
        XCTAssertEqual(display.answerVM?.summary?.isThemeMastered, true)
    }

    func test_presentAnswer_finishedLowAccuracy_notMastered() async {
        let (sut, display) = makeSUT()
        await sut.presentAnswer(response: .init(
            wasCorrect: false,
            isFinished: true,
            nextRound: nil,
            nextRoundIndex: nil,
            correctCount: 2,
            totalRounds: 8
        ))
        XCTAssertEqual(display.answerVM?.summary?.isThemeMastered, false)
    }
}
