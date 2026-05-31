@testable import HappySpeech
import XCTest

// MARK: - Spy DisplayLogic

@MainActor
private final class SpySentenceBuilderDisplay: SentenceBuilderDisplayLogic, @unchecked Sendable {
    var startVM: SentenceBuilderModels.Start.ViewModel?
    var answerVM: SentenceBuilderModels.Answer.ViewModel?

    func displayStart(viewModel: SentenceBuilderModels.Start.ViewModel) async {
        startVM = viewModel
    }
    func displayAnswer(viewModel: SentenceBuilderModels.Answer.ViewModel) async {
        answerVM = viewModel
    }
}

// MARK: - Helpers

@MainActor
private func makeOrderRound() -> SentenceRound {
    SentenceRound(
        id: "r-order", subtask: .wordOrder, sceneImage: "cat.fill",
        bankTokens: [
            .init(id: "o0", text: "кот", role: .subject),
            .init(id: "o1", text: "спит", role: .verb),
            .init(id: "o2", text: "на", role: .prep),
            .init(id: "o3", text: "диване", role: .object)
        ],
        slotCount: 4,
        acceptedOrders: [["o0", "o1", "o2", "o3"]],
        spokenSentence: "Кот спит на диване.", difficulty: 1, minAge: 6
    )
}

@MainActor
private func makeAgreementRound() -> SentenceRound {
    SentenceRound(
        id: "r-agree", subtask: .agreement, sceneImage: "apple.logo",
        bankTokens: [
            .init(id: "a0", text: "красный", role: .adjective),
            .init(id: "a1", text: "красная", role: .adjective),
            .init(id: "a2", text: "красное", role: .adjective),
            .init(id: "a3", text: "яблоко", role: .noun)
        ],
        slotCount: 2,
        acceptedOrders: [["a2", "a3"]],
        spokenSentence: "Красное яблоко.", difficulty: 2, minAge: 6
    )
}

// MARK: - Presenter Tests

@MainActor
final class SentenceBuilderPresenterTests: XCTestCase {

    private func makeSUT() -> (SentenceBuilderPresenter, SpySentenceBuilderDisplay) {
        let display = SpySentenceBuilderDisplay()
        let sut = SentenceBuilderPresenter(displayLogic: display)
        return (sut, display)
    }

    // MARK: Start

    func test_presentStart_buildsViewModelWithFirstRound() async {
        let (sut, display) = makeSUT()
        let rounds = [makeOrderRound(), makeAgreementRound()]
        await sut.presentStart(response: .init(rounds: rounds, soundTarget: "грамматика.синтаксис", childAge: 6))
        XCTAssertNotNil(display.startVM)
        XCTAssertEqual(display.startVM?.totalRounds, 2)
        XCTAssertEqual(display.startVM?.firstRound.bankCards.count, 4)
        XCTAssertEqual(display.startVM?.firstRound.slotCount, 4)
        XCTAssertFalse(display.startVM?.firstRound.promptLyalya.isEmpty ?? true)
        XCTAssertEqual(display.startVM?.firstRound.sceneImage, "cat.fill")
    }

    func test_presentStart_emptyRounds_doesNotDisplay() async {
        let (sut, display) = makeSUT()
        await sut.presentStart(response: .init(rounds: [], soundTarget: "грамматика.синтаксис", childAge: 6))
        XCTAssertNil(display.startVM)
    }

    // MARK: serverside truth hidden from CardViewModel

    func test_cardViewModel_doesNotExposeDistractorFlagOrAcceptedOrders() async {
        let (sut, display) = makeSUT()
        await sut.presentStart(response: .init(rounds: [makeAgreementRound()], soundTarget: "грамматика.синтаксис", childAge: 6))
        let cards = display.startVM?.firstRound.bankCards ?? []
        XCTAssertEqual(cards.count, 4)
        let mirror = Mirror(reflecting: cards[0])
        let labels = mirror.children.compactMap(\.label)
        XCTAssertFalse(labels.contains("isDistractor"), "CardViewModel не должен раскрывать isDistractor")
        // RoundViewModel не должен раскрывать acceptedOrders.
        let roundMirror = Mirror(reflecting: display.startVM!.firstRound)
        let roundLabels = roundMirror.children.compactMap(\.label)
        XCTAssertFalse(roundLabels.contains("acceptedOrders"), "RoundViewModel не должен раскрывать acceptedOrders")
    }

    func test_bankCards_includeAllWords() async {
        let (sut, display) = makeSUT()
        await sut.presentStart(response: .init(rounds: [makeOrderRound()], soundTarget: "грамматика.синтаксис", childAge: 6))
        let words = Set((display.startVM?.firstRound.bankCards ?? []).map(\.text))
        XCTAssertEqual(words, ["кот", "спит", "на", "диване"])
    }

    // MARK: Prompt by subtask

    func test_subtaskPrompts_differ() {
        let order = SentenceBuilderPresenter.subtaskPrompt(.wordOrder)
        let agree = SentenceBuilderPresenter.subtaskPrompt(.agreement)
        let prep = SentenceBuilderPresenter.subtaskPrompt(.preposition)
        XCTAssertFalse(order.isEmpty)
        XCTAssertNotEqual(order, agree)
        XCTAssertNotEqual(agree, prep)
        XCTAssertNotEqual(order, prep)
    }

    // MARK: Card a11y by role

    func test_cardAccessibilityLabel_prepDiffersFromWord() {
        let prepToken = SentenceToken(id: "p", text: "на", role: .prep)
        let wordToken = SentenceToken(id: "w", text: "кот", role: .subject)
        let prepLabel = SentenceBuilderPresenter.cardAccessibilityLabel(prepToken)
        let wordLabel = SentenceBuilderPresenter.cardAccessibilityLabel(wordToken)
        XCTAssertNotEqual(prepLabel, wordLabel)
        XCTAssertTrue(prepLabel.contains("на"))
        XCTAssertTrue(wordLabel.contains("кот"))
    }

    // MARK: Feedback («светофор», без «неправильно»)

    func test_feedbackLine_hit_voicesSentence() {
        let line = SentenceBuilderPresenter.feedbackLine(tier: .hit, spokenSentence: "Кот спит на диване.")
        XCTAssertFalse(line.isEmpty)
        XCTAssertTrue(line.contains("Кот спит на диване."))
    }

    func test_feedbackLine_neverContainsWrongWord() {
        for tier in [FeedbackTier.hit, .almost, .retry] {
            let line = SentenceBuilderPresenter.feedbackLine(tier: tier, spokenSentence: "Кот спит на диване.")
            XCTAssertFalse(line.lowercased().contains("неправильно"),
                           "Реплика \(tier) не должна содержать «неправильно»")
            XCTAssertFalse(line.lowercased().contains("ошибк"),
                           "Реплика \(tier) не должна содержать «ошибка»")
        }
    }

    func test_presentAnswer_hit_setsFeedbackNextAndSentence() async {
        let (sut, display) = makeSUT()
        await sut.presentAnswer(response: .init(
            feedback: .hit,
            correctOrder: ["o0", "o1", "o2", "o3"],
            spokenSentence: "Кот спит на диване.",
            firstHintTokenId: nil,
            showHint: false,
            advancedToNextRound: true,
            isFinished: false,
            nextRound: makeAgreementRound(),
            nextRoundIndex: 1,
            correctCount: 1,
            totalRounds: 2
        ))
        XCTAssertEqual(display.answerVM?.feedback, .hit)
        XCTAssertFalse(display.answerVM?.lyalyaLine.isEmpty ?? true)
        XCTAssertNotNil(display.answerVM?.nextRound)
        XCTAssertNil(display.answerVM?.summary)
        XCTAssertEqual(display.answerVM?.spokenSentence, "Кот спит на диване.")
        XCTAssertTrue(display.answerVM?.highlightOrder.isEmpty ?? false, "На hit подсветки слотов нет")
    }

    func test_presentAnswer_retryWithHint_setsHintAndHighlightOrder() async {
        let (sut, display) = makeSUT()
        await sut.presentAnswer(response: .init(
            feedback: .retry,
            correctOrder: ["o0", "o1", "o2", "o3"],
            spokenSentence: "",
            firstHintTokenId: "o0",
            showHint: true,
            advancedToNextRound: true,
            isFinished: false,
            nextRound: nil,
            nextRoundIndex: nil,
            correctCount: 0,
            totalRounds: 2
        ))
        XCTAssertEqual(display.answerVM?.feedback, .retry)
        XCTAssertEqual(display.answerVM?.hintTokenId, "o0")
        XCTAssertEqual(display.answerVM?.highlightOrder, ["o0", "o1", "o2", "o3"], "На retry слоты подсвечиваются в каноническом порядке")
    }

    // MARK: Summary

    func test_presentAnswer_finished_buildsSummary_withCelebration() async {
        let (sut, display) = makeSUT()
        await sut.presentAnswer(response: .init(
            feedback: .hit,
            correctOrder: ["o0", "o1", "o2", "o3"],
            spokenSentence: "Кот спит на диване.",
            firstHintTokenId: nil,
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
            correctOrder: ["o0", "o1", "o2", "o3"],
            spokenSentence: "",
            firstHintTokenId: nil,
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
        let vm = SentenceBuilderPresenter.makeRoundVM(makeOrderRound(), index: 2, total: 10)
        XCTAssertFalse(vm.progressLabel.isEmpty)
        XCTAssertEqual(vm.progressFraction, 0.3, accuracy: 0.0001)
        XCTAssertFalse(vm.accessibilityLabel.isEmpty)
        XCTAssertEqual(vm.bankCards.count, 4)
    }
}
