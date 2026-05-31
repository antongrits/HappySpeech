@testable import HappySpeech
import XCTest

// MARK: - Spy DisplayLogic

@MainActor
private final class SpyWhoseTailDisplay: WhoseTailDisplayLogic, @unchecked Sendable {
    var startVM: WhoseTailModels.Start.ViewModel?
    var answerVM: WhoseTailModels.Answer.ViewModel?

    func displayStart(viewModel: WhoseTailModels.Start.ViewModel) async {
        startVM = viewModel
    }
    func displayAnswer(viewModel: WhoseTailModels.Answer.ViewModel) async {
        answerVM = viewModel
    }
}

// MARK: - Helpers

@MainActor
private func makePossessiveRound() -> WhoseRound {
    let options = [
        WhoseOption(id: "o0", word: "лиса", imageAsset: "word_fox", isCorrect: true, form: "лисий хвост"),
        WhoseOption(id: "o1", word: "заяц", imageAsset: "word_hare", isCorrect: false, form: "заячий хвост")
    ]
    return WhoseRound(
        id: "r-poss", subtask: .possessiveTail, cueImage: "pawprint.fill",
        question: "Чей это хвост?", options: options,
        spokenForm: "Это лисий хвост.", difficulty: 1, minAge: 5
    )
}

@MainActor
private func makeHomeRound() -> WhoseRound {
    let options = [
        WhoseOption(id: "h0", word: "лиса", imageAsset: "word_fox", isCorrect: true, form: "лисья нора"),
        WhoseOption(id: "h1", word: "белка", imageAsset: "word_belka", isCorrect: false, form: "беличье дупло"),
        WhoseOption(id: "h2", word: "медведь", imageAsset: "word_bear", isCorrect: false, form: "медвежья берлога")
    ]
    return WhoseRound(
        id: "r-home", subtask: .animalHome, cueImage: "mountain.2.fill",
        question: "Чей это домик? Чья это нора?", options: options,
        spokenForm: "Это лисья нора.", difficulty: 3, minAge: 7
    )
}

// MARK: - Presenter Tests

@MainActor
final class WhoseTailPresenterTests: XCTestCase {

    private func makeSUT() -> (WhoseTailPresenter, SpyWhoseTailDisplay) {
        let display = SpyWhoseTailDisplay()
        let sut = WhoseTailPresenter(displayLogic: display)
        return (sut, display)
    }

    // MARK: Start

    func test_presentStart_buildsViewModelWithFirstRound() async {
        let (sut, display) = makeSUT()
        let rounds = [makePossessiveRound(), makeHomeRound()]
        await sut.presentStart(response: .init(rounds: rounds, soundTarget: "грамматика.притяжат", childAge: 6))
        XCTAssertNotNil(display.startVM)
        XCTAssertEqual(display.startVM?.totalRounds, 2)
        XCTAssertEqual(display.startVM?.firstRound.options.count, 2)
        XCTAssertFalse(display.startVM?.firstRound.promptLyalya.isEmpty ?? true)
        XCTAssertEqual(display.startVM?.firstRound.cueImage, "pawprint.fill")
    }

    func test_presentStart_emptyRounds_doesNotDisplay() async {
        let (sut, display) = makeSUT()
        await sut.presentStart(response: .init(rounds: [], soundTarget: "грамматика.притяжат", childAge: 6))
        XCTAssertNil(display.startVM)
    }

    // MARK: isCorrect/form hidden from OptionViewModel (методическое правило)

    func test_optionViewModel_doesNotExposeCorrectnessOrForm() async {
        let (sut, display) = makeSUT()
        await sut.presentStart(response: .init(rounds: [makeHomeRound()], soundTarget: "грамматика.притяжат", childAge: 6))
        let options = display.startVM?.firstRound.options ?? []
        XCTAssertEqual(options.count, 3)
        let mirror = Mirror(reflecting: options[0])
        let labels = mirror.children.compactMap(\.label)
        XCTAssertFalse(labels.contains("isCorrect"), "OptionViewModel не должен раскрывать isCorrect")
        XCTAssertFalse(labels.contains("form"), "OptionViewModel не должен раскрывать целевую форму до hit")
    }

    func test_options_includeAllWords() async {
        let (sut, display) = makeSUT()
        await sut.presentStart(response: .init(rounds: [makeHomeRound()], soundTarget: "грамматика.притяжат", childAge: 6))
        let words = Set((display.startVM?.firstRound.options ?? []).map(\.word))
        XCTAssertEqual(words, ["лиса", "белка", "медведь"])
    }

    // MARK: Prompt by subtask

    func test_subtaskPrompts_differ() {
        let poss = WhoseTailPresenter.subtaskPrompt(.possessiveTail)
        let home = WhoseTailPresenter.subtaskPrompt(.animalHome)
        let rel = WhoseTailPresenter.subtaskPrompt(.relativeMaterial)
        XCTAssertFalse(poss.isEmpty)
        XCTAssertNotEqual(poss, rel)
        XCTAssertNotEqual(home, rel)
    }

    func test_prompt_usesPackQuestionWhenPresent() {
        let line = WhoseTailPresenter.prompt(for: makePossessiveRound())
        XCTAssertEqual(line, "Чей это хвост?", "Реплика берётся из pack-question")
    }

    // MARK: Feedback («светофор», без «неправильно»)

    func test_feedbackLine_hit_voicesTargetForm() {
        let line = WhoseTailPresenter.feedbackLine(tier: .hit, spokenForm: "Это лисий хвост.")
        XCTAssertFalse(line.isEmpty)
        XCTAssertTrue(line.contains("Это лисий хвост."))
    }

    func test_feedbackLine_neverContainsWrongWord() {
        for tier in [FeedbackTier.hit, .almost, .retry] {
            let line = WhoseTailPresenter.feedbackLine(tier: tier, spokenForm: "Это лисий хвост.")
            XCTAssertFalse(line.lowercased().contains("неправильно"),
                           "Реплика \(tier) не должна содержать «неправильно»")
            XCTAssertFalse(line.lowercased().contains("ошибк"),
                           "Реплика \(tier) не должна содержать «ошибка»")
        }
    }

    func test_presentAnswer_hit_setsFeedbackAndNext() async {
        let (sut, display) = makeSUT()
        await sut.presentAnswer(response: .init(
            feedback: .hit,
            correctOptionId: "o0",
            spokenForm: "Это лисий хвост.",
            askToRepeat: false,
            hintOptionId: nil,
            showHint: false,
            advancedToNextRound: true,
            isFinished: false,
            nextRound: makeHomeRound(),
            nextRoundIndex: 1,
            correctCount: 1,
            totalRounds: 2
        ))
        XCTAssertEqual(display.answerVM?.feedback, .hit)
        XCTAssertFalse(display.answerVM?.lyalyaLine.isEmpty ?? true)
        XCTAssertNotNil(display.answerVM?.nextRound)
        XCTAssertNil(display.answerVM?.summary)
        XCTAssertEqual(display.answerVM?.spokenForm, "Это лисий хвост.")
    }

    func test_presentAnswer_retryWithHint_setsHintOptionId() async {
        let (sut, display) = makeSUT()
        await sut.presentAnswer(response: .init(
            feedback: .retry,
            correctOptionId: "o0",
            spokenForm: "",
            askToRepeat: false,
            hintOptionId: "o0",
            showHint: true,
            advancedToNextRound: true,
            isFinished: false,
            nextRound: nil,
            nextRoundIndex: nil,
            correctCount: 0,
            totalRounds: 2
        ))
        XCTAssertEqual(display.answerVM?.feedback, .retry)
        XCTAssertEqual(display.answerVM?.hintOptionId, "o0")
    }

    // MARK: Summary

    func test_presentAnswer_finished_buildsSummary_withCelebration() async {
        let (sut, display) = makeSUT()
        await sut.presentAnswer(response: .init(
            feedback: .hit,
            correctOptionId: "o0",
            spokenForm: "Это лисий хвост.",
            askToRepeat: false,
            hintOptionId: nil,
            showHint: false,
            advancedToNextRound: true,
            isFinished: true,
            nextRound: nil,
            nextRoundIndex: nil,
            correctCount: 9,
            totalRounds: 10
        ))
        XCTAssertEqual(display.answerVM?.isFinished, true)
        XCTAssertNotNil(display.answerVM?.summary)
        XCTAssertEqual(display.answerVM?.summary?.accuracyFraction ?? 0, 0.9, accuracy: 0.0001)
        XCTAssertTrue(display.answerVM?.summary?.showCelebration ?? false, "≥80% → праздник")
        XCTAssertFalse(display.answerVM?.summary?.encouragement.isEmpty ?? true)
    }

    func test_presentAnswer_finishedLowAccuracy_noCelebration_stillEncourages() async {
        let (sut, display) = makeSUT()
        await sut.presentAnswer(response: .init(
            feedback: .retry,
            correctOptionId: "o0",
            spokenForm: "",
            askToRepeat: false,
            hintOptionId: nil,
            showHint: true,
            advancedToNextRound: true,
            isFinished: true,
            nextRound: nil,
            nextRoundIndex: nil,
            correctCount: 2,
            totalRounds: 10
        ))
        XCTAssertFalse(display.answerVM?.summary?.showCelebration ?? true)
        XCTAssertFalse(display.answerVM?.summary?.encouragement.isEmpty ?? true)
    }

    // MARK: Round VM details

    func test_makeRoundVM_progressLabelAndFraction() {
        let vm = WhoseTailPresenter.makeRoundVM(makePossessiveRound(), index: 2, total: 10)
        XCTAssertFalse(vm.progressLabel.isEmpty)
        XCTAssertEqual(vm.progressFraction, 0.3, accuracy: 0.0001)
        XCTAssertFalse(vm.accessibilityLabel.isEmpty)
        XCTAssertEqual(vm.options.count, 2)
    }
}
