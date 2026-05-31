@testable import HappySpeech
import XCTest

// MARK: - Spy DisplayLogic

@MainActor
private final class SpyWordFormationDisplay: WordFormationDisplayLogic, @unchecked Sendable {
    var startVM: WordFormationModels.Start.ViewModel?
    var answerVM: WordFormationModels.Answer.ViewModel?

    func displayStart(viewModel: WordFormationModels.Start.ViewModel) async {
        startVM = viewModel
    }
    func displayAnswer(viewModel: WordFormationModels.Answer.ViewModel) async {
        answerVM = viewModel
    }
}

// MARK: - Helpers

@MainActor
private func makeDiminutiveRound() -> FormationRound {
    let options = [
        FormationOption(id: "o0", text: "столик", isCorrect: true),
        FormationOption(id: "o1", text: "столёнок", isCorrect: false)
    ]
    return FormationRound(
        id: "r-dim", subtask: .diminutive, baseWord: "стол", baseImage: "word_stol",
        prompt: "Назови ласково", options: options, spokenForm: "Столик.",
        difficulty: 1, minAge: 5
    )
}

@MainActor
private func makeManyOfRound() -> FormationRound {
    let options = [
        FormationOption(id: "m0", text: "много стульев", isCorrect: true),
        FormationOption(id: "m1", text: "много стулов", isCorrect: false, isNearMiss: true),
        FormationOption(id: "m2", text: "много стулья", isCorrect: false)
    ]
    return FormationRound(
        id: "r-many", subtask: .manyOf, baseWord: "стул", baseImage: "word_stul",
        prompt: "Чего много?", options: options, spokenForm: "Много стульев.",
        difficulty: 3, minAge: 6
    )
}

// MARK: - Presenter Tests

@MainActor
final class WordFormationPresenterTests: XCTestCase {

    private func makeSUT() -> (WordFormationPresenter, SpyWordFormationDisplay) {
        let display = SpyWordFormationDisplay()
        let sut = WordFormationPresenter(displayLogic: display)
        return (sut, display)
    }

    // MARK: Start

    func test_presentStart_buildsViewModelWithFirstRound() async {
        let (sut, display) = makeSUT()
        let rounds = [makeDiminutiveRound(), makeManyOfRound()]
        await sut.presentStart(response: .init(rounds: rounds, soundTarget: "грамматика.словообр", childAge: 6))
        XCTAssertNotNil(display.startVM)
        XCTAssertEqual(display.startVM?.totalRounds, 2)
        XCTAssertEqual(display.startVM?.firstRound.options.count, 2)
        XCTAssertFalse(display.startVM?.firstRound.promptLyalya.isEmpty ?? true)
        XCTAssertEqual(display.startVM?.firstRound.baseWord, "стол")
        XCTAssertEqual(display.startVM?.firstRound.baseImage, "word_stol")
    }

    func test_presentStart_emptyRounds_doesNotDisplay() async {
        let (sut, display) = makeSUT()
        await sut.presentStart(response: .init(rounds: [], soundTarget: "грамматика.словообр", childAge: 6))
        XCTAssertNil(display.startVM)
    }

    // MARK: isCorrect/isNearMiss hidden from ViewModel (методическое правило)

    func test_optionViewModel_doesNotExposeCorrectness() async {
        let (sut, display) = makeSUT()
        await sut.presentStart(response: .init(rounds: [makeManyOfRound()], soundTarget: "грамматика.словообр", childAge: 6))
        let options = display.startVM?.firstRound.options ?? []
        XCTAssertEqual(options.count, 3)
        let mirror = Mirror(reflecting: options[0])
        let labels = mirror.children.compactMap(\.label)
        XCTAssertFalse(labels.contains("isCorrect"), "OptionViewModel не должен раскрывать isCorrect")
        XCTAssertFalse(labels.contains("isNearMiss"))
    }

    func test_options_includeAllFormTexts() async {
        let (sut, display) = makeSUT()
        await sut.presentStart(response: .init(rounds: [makeManyOfRound()], soundTarget: "грамматика.словообр", childAge: 6))
        let texts = Set((display.startVM?.firstRound.options ?? []).map(\.text))
        XCTAssertEqual(texts, ["много стульев", "много стулов", "много стулья"])
    }

    // MARK: Prompt by subtask

    func test_subtaskPrompts_differ() {
        let dim = WordFormationPresenter.subtaskPrompt(.diminutive)
        let one = WordFormationPresenter.subtaskPrompt(.oneMany)
        let many = WordFormationPresenter.subtaskPrompt(.manyOf)
        XCTAssertFalse(dim.isEmpty)
        XCTAssertNotEqual(dim, one)
        XCTAssertNotEqual(one, many)
    }

    func test_prompt_usesPackPromptWhenPresent() {
        let line = WordFormationPresenter.prompt(for: makeManyOfRound())
        XCTAssertEqual(line, "Чего много?", "Реплика берётся из pack-prompt")
    }

    // MARK: Feedback («светофор», без «неправильно»)

    func test_feedbackLine_hit_voicesNormativeForm() {
        let line = WordFormationPresenter.feedbackLine(tier: .hit, spokenForm: "Много стульев.", wasNearMiss: false)
        XCTAssertFalse(line.isEmpty)
        XCTAssertTrue(line.contains("Много стульев."))
    }

    func test_feedbackLine_almost_nearMiss_differsFromGross() {
        let near = WordFormationPresenter.feedbackLine(tier: .almost, spokenForm: "", wasNearMiss: true)
        let gross = WordFormationPresenter.feedbackLine(tier: .almost, spokenForm: "", wasNearMiss: false)
        XCTAssertFalse(near.isEmpty)
        XCTAssertFalse(gross.isEmpty)
        XCTAssertNotEqual(near, gross, "Близкая ошибка имеет более мягкую реплику")
    }

    func test_feedbackLine_neverContainsWrongWord() {
        for tier in [FeedbackTier.hit, .almost, .retry] {
            for near in [true, false] {
                let line = WordFormationPresenter.feedbackLine(tier: tier, spokenForm: "Столик.", wasNearMiss: near)
                XCTAssertFalse(line.lowercased().contains("неправильно"),
                               "Реплика \(tier) не должна содержать «неправильно»")
                XCTAssertFalse(line.lowercased().contains("ошибк"),
                               "Реплика \(tier) не должна содержать «ошибка»")
            }
        }
    }

    func test_presentAnswer_hit_setsFeedbackAndNext() async {
        let (sut, display) = makeSUT()
        await sut.presentAnswer(response: .init(
            feedback: .hit,
            correctOptionId: "o0",
            spokenForm: "Столик.",
            chosenWasNearMiss: false,
            askToRepeat: false,
            hintOptionId: nil,
            showHint: false,
            advancedToNextRound: true,
            isFinished: false,
            nextRound: makeManyOfRound(),
            nextRoundIndex: 1,
            correctCount: 1,
            totalRounds: 2
        ))
        XCTAssertEqual(display.answerVM?.feedback, .hit)
        XCTAssertFalse(display.answerVM?.lyalyaLine.isEmpty ?? true)
        XCTAssertNotNil(display.answerVM?.nextRound)
        XCTAssertNil(display.answerVM?.summary)
        XCTAssertEqual(display.answerVM?.spokenForm, "Столик.")
    }

    func test_presentAnswer_retryWithHint_setsHintOptionId() async {
        let (sut, display) = makeSUT()
        await sut.presentAnswer(response: .init(
            feedback: .retry,
            correctOptionId: "o0",
            spokenForm: "",
            chosenWasNearMiss: false,
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
            spokenForm: "Столик.",
            chosenWasNearMiss: false,
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
            chosenWasNearMiss: false,
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
        let vm = WordFormationPresenter.makeRoundVM(makeDiminutiveRound(), index: 2, total: 10)
        XCTAssertFalse(vm.progressLabel.isEmpty)
        XCTAssertEqual(vm.progressFraction, 0.3, accuracy: 0.0001)
        XCTAssertFalse(vm.accessibilityLabel.isEmpty)
        XCTAssertEqual(vm.options.count, 2)
    }
}
