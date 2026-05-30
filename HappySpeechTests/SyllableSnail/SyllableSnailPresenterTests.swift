@testable import HappySpeech
import XCTest

// MARK: - Spy DisplayLogic

@MainActor
private final class SpySnailDisplay: SyllableSnailDisplayLogic, @unchecked Sendable {
    var startVM: SyllableSnailModels.Start.ViewModel?
    var tapVM: SyllableSnailModels.Tap.ViewModel?
    var submitVM: SyllableSnailModels.Submit.ViewModel?
    var fixVM: SyllableSnailModels.Fix.ViewModel?

    func displayStart(viewModel: SyllableSnailModels.Start.ViewModel) async { startVM = viewModel }
    func displayTap(viewModel: SyllableSnailModels.Tap.ViewModel) async { tapVM = viewModel }
    func displaySubmit(viewModel: SyllableSnailModels.Submit.ViewModel) async { submitVM = viewModel }
    func displayFix(viewModel: SyllableSnailModels.Fix.ViewModel) async { fixVM = viewModel }
}

@MainActor
private func makeWord(
    syllables: [String] = ["ма", "ши", "на"],
    mode: SnailMode
) -> SnailWord {
    SnailWord(
        base: SyllableWord(id: "w", word: "машина", syllables: syllables, tier: .threeSyllablesWithClosed),
        imageAsset: "word_car",
        markovaClass: 6,
        audioSyllables: syllables,
        scrambledHints: []
    )
}

@MainActor
private func makeRound(mode: SnailMode, syllables: [String] = ["ма", "ши", "на"]) -> SnailRound {
    let word = makeWord(syllables: syllables, mode: mode)
    let tiles: [SyllableTile] = (mode == .clap) ? [] : word.syllables.enumerated().map {
        SyllableTile(id: "w-\($0.offset)-\($0.element)", text: $0.element)
    }
    return SnailRound(id: "\(mode.rawValue)-w-0", word: word, mode: mode, tiles: tiles)
}

@MainActor
final class SyllableSnailPresenterTests: XCTestCase {

    private func makeSUT() -> (SyllableSnailPresenter, SpySnailDisplay) {
        let display = SpySnailDisplay()
        let presenter = SyllableSnailPresenter(displayLogic: display)
        return (presenter, display)
    }

    // MARK: Start

    func test_presentStart_buildsFirstRoundVM() async {
        let (presenter, display) = makeSUT()
        let round = makeRound(mode: .clap)
        await presenter.presentStart(response: .init(mode: .clap, tier: .threeSyllablesWithClosed, rounds: [round, round]))
        XCTAssertNotNil(display.startVM)
        XCTAssertEqual(display.startVM?.totalRounds, 2)
        XCTAssertEqual(display.startVM?.firstRound.pathSlotsCount, 3)
        XCTAssertEqual(display.startVM?.firstRound.mode, .clap)
        XCTAssertFalse(display.startVM?.firstRound.promptLyalya.isEmpty ?? true)
        XCTAssertFalse(display.startVM?.modeLabel.isEmpty ?? true)
    }

    func test_presentStart_emptyRounds_doesNotCrash() async {
        let (presenter, display) = makeSUT()
        await presenter.presentStart(response: .init(mode: .clap, tier: .oneSyllableOpen, rounds: []))
        XCTAssertNil(display.startVM)
    }

    func test_buildMode_roundVM_hasTilesWithA11y() async {
        let (presenter, display) = makeSUT()
        let round = makeRound(mode: .build)
        await presenter.presentStart(response: .init(mode: .build, tier: .threeSyllablesWithClosed, rounds: [round]))
        let tiles = display.startVM?.firstRound.tiles ?? []
        XCTAssertEqual(tiles.count, 3)
        XCTAssertTrue(tiles.allSatisfy { !$0.accessibilityLabel.isEmpty })
    }

    // MARK: Feedback («светофор» — без «неправильно»)

    func test_presentTap_hit_buildsHomeReachedLine() async {
        let (presenter, display) = makeSUT()
        let response = SyllableSnailModels.Tap.Response(
            feedback: .hit, expectedSyllables: 3, gotTaps: 3, replayBySyllable: false,
            snailReachedHome: true, showHint: false, advancedToNextRound: true,
            isFinished: false, nextRound: makeRound(mode: .clap), nextRoundIndex: 1,
            correctCount: 1, totalRounds: 2
        )
        await presenter.presentTap(response: response)
        XCTAssertEqual(display.tapVM?.feedback, .hit)
        XCTAssertFalse(display.tapVM?.lyalyaLine.isEmpty ?? true)
        XCTAssertNotNil(display.tapVM?.nextRound)
    }

    func test_presentTap_retry_lineMentionsSyllableCount() async {
        let (presenter, display) = makeSUT()
        let response = SyllableSnailModels.Tap.Response(
            feedback: .retry, expectedSyllables: 3, gotTaps: 5, replayBySyllable: true,
            snailReachedHome: false, showHint: true, advancedToNextRound: true,
            isFinished: false, nextRound: makeRound(mode: .clap), nextRoundIndex: 1,
            correctCount: 0, totalRounds: 2
        )
        await presenter.presentTap(response: response)
        XCTAssertEqual(display.tapVM?.feedback, .retry)
        XCTAssertTrue(display.tapVM?.showHint ?? false)
    }

    func test_presentFix_finished_buildsSummary() async {
        let (presenter, display) = makeSUT()
        let response = SyllableSnailModels.Fix.Response(
            feedback: .hit, assembled: "машина", expected: "машина", snailReachedHome: true,
            replayBySyllable: false, firstWrongSlotIndex: nil, showHint: false,
            advancedToNextRound: true, isFinished: true, nextRound: nil, nextRoundIndex: nil,
            correctCount: 2, totalRounds: 2
        )
        await presenter.presentFix(response: response)
        XCTAssertNotNil(display.fixVM?.summary)
        XCTAssertEqual(display.fixVM?.summary?.correctCount, 2)
        XCTAssertEqual(display.fixVM?.summary?.totalRounds, 2)
        XCTAssertTrue(display.fixVM?.summary?.showCelebration ?? false, "100% → праздник")
    }

    func test_presentSubmit_lowAccuracy_noCelebration() async {
        let (presenter, display) = makeSUT()
        let response = SyllableSnailModels.Submit.Response(
            feedback: .retry, assembled: "наши", expected: "машина", snailReachedHome: false,
            replayBySyllable: true, firstWrongSlotIndex: 0, showHint: true,
            advancedToNextRound: true, isFinished: true, nextRound: nil, nextRoundIndex: nil,
            correctCount: 1, totalRounds: 4
        )
        await presenter.presentSubmit(response: response)
        XCTAssertNotNil(display.submitVM?.summary)
        XCTAssertFalse(display.submitVM?.summary?.showCelebration ?? true, "25% → без праздника")
    }

    // MARK: Labels / prompts

    func test_modeLabels_areNonEmpty() {
        XCTAssertFalse(SyllableSnailPresenter.modeLabel(.clap).isEmpty)
        XCTAssertFalse(SyllableSnailPresenter.modeLabel(.build).isEmpty)
        XCTAssertFalse(SyllableSnailPresenter.modeLabel(.fix).isEmpty)
    }

    func test_prompts_differByMode() {
        let clap = SyllableSnailPresenter.prompt(for: .clap, word: "машина")
        let build = SyllableSnailPresenter.prompt(for: .build, word: "машина")
        let fix = SyllableSnailPresenter.prompt(for: .fix, word: "машина")
        XCTAssertNotEqual(clap, build)
        XCTAssertNotEqual(build, fix)
    }
}
