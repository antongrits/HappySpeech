@testable import HappySpeech
import XCTest

// MARK: - Spy DisplayLogic

@MainActor
private final class SpyFourthExtraDisplay: FourthExtraDisplayLogic, @unchecked Sendable {
    var startVM: FourthExtraModels.Start.ViewModel?
    var answerVM: FourthExtraModels.Answer.ViewModel?

    func displayStart(viewModel: FourthExtraModels.Start.ViewModel) async {
        startVM = viewModel
    }
    func displayAnswer(viewModel: FourthExtraModels.Answer.ViewModel) async {
        answerVM = viewModel
    }
}

// MARK: - Helpers

@MainActor
private func makeSemanticRound(extraIndex: Int = 3) -> FourthExtraRound {
    let words = ["яблоко", "груша", "банан", "стул"]
    let assets = ["word_apple", "word_grusha", "word_banan", "word_stul"]
    let cards = (0..<4).map { idx in
        ExtraCard(
            id: "c\(idx)", word: words[idx], imageAsset: assets[idx],
            isExtra: idx == extraIndex,
            extraReason: idx == extraIndex ? "это мебель" : nil
        )
    }
    return FourthExtraRound(
        id: "r-sem", variant: .semantic, rule: .category,
        categoryLabel: "фрукты", targetSound: nil,
        cards: cards, difficulty: 1, minAge: 5
    )
}

@MainActor
private func makePhoneticRound() -> FourthExtraRound {
    let cards = [
        ExtraCard(id: "p0", word: "шапка", imageAsset: "word_hat", isExtra: false, extraReason: nil),
        ExtraCard(id: "p1", word: "шуба", imageAsset: "word_shuba", isExtra: false, extraReason: nil),
        ExtraCard(id: "p2", word: "машина", imageAsset: "word_car", isExtra: false, extraReason: nil),
        ExtraCard(id: "p3", word: "рак", imageAsset: "word_rak", isExtra: true, extraReason: "в слове нет звука Ш")
    ]
    return FourthExtraRound(
        id: "r-phon", variant: .phonetic, rule: .sound,
        categoryLabel: nil, targetSound: "Ш",
        cards: cards, difficulty: 2, minAge: 6
    )
}

// MARK: - Presenter Tests

@MainActor
final class FourthExtraPresenterTests: XCTestCase {

    private func makeSUT() -> (FourthExtraPresenter, SpyFourthExtraDisplay) {
        let display = SpyFourthExtraDisplay()
        let sut = FourthExtraPresenter(displayLogic: display)
        return (sut, display)
    }

    // MARK: Start

    func test_presentStart_buildsViewModelWithFirstRound() async {
        let (sut, display) = makeSUT()
        let rounds = [makeSemanticRound(), makePhoneticRound()]
        await sut.presentStart(response: .init(rounds: rounds, soundTarget: "лексика", childAge: 6))
        XCTAssertNotNil(display.startVM)
        XCTAssertEqual(display.startVM?.totalRounds, 2)
        XCTAssertEqual(display.startVM?.firstRound.cards.count, 4)
        XCTAssertFalse(display.startVM?.firstRound.promptLyalya.isEmpty ?? true)
    }

    func test_presentStart_emptyRounds_doesNotDisplay() async {
        let (sut, display) = makeSUT()
        await sut.presentStart(response: .init(rounds: [], soundTarget: "лексика", childAge: 6))
        XCTAssertNil(display.startVM)
    }

    // MARK: isExtra hidden from ViewModel (методическое правило)

    func test_cardViewModel_doesNotExposeIsExtra() async {
        // CardViewModel не содержит поля isExtra — ответ нельзя «подсмотреть».
        let (sut, display) = makeSUT()
        await sut.presentStart(response: .init(rounds: [makeSemanticRound(extraIndex: 2)], soundTarget: "лексика", childAge: 6))
        let cards = display.startVM?.firstRound.cards ?? []
        XCTAssertEqual(cards.count, 4)
        let mirror = Mirror(reflecting: cards[0])
        let labels = mirror.children.compactMap(\.label)
        XCTAssertFalse(labels.contains("isExtra"), "CardViewModel не должен раскрывать isExtra")
        XCTAssertFalse(labels.contains("extraReason"))
    }

    func test_cards_includeAllWordsAndAssets() async {
        let (sut, display) = makeSUT()
        await sut.presentStart(response: .init(rounds: [makeSemanticRound()], soundTarget: "лексика", childAge: 6))
        let words = Set((display.startVM?.firstRound.cards ?? []).map(\.word))
        XCTAssertEqual(words, ["яблоко", "груша", "банан", "стул"])
    }

    // MARK: Prompt by variant

    func test_prompt_semanticVsPhonetic_differ() {
        let semPrompt = FourthExtraPresenter.prompt(for: makeSemanticRound())
        let phonPrompt = FourthExtraPresenter.prompt(for: makePhoneticRound())
        XCTAssertFalse(semPrompt.isEmpty)
        XCTAssertFalse(phonPrompt.isEmpty)
        XCTAssertNotEqual(semPrompt, phonPrompt)
        XCTAssertTrue(phonPrompt.contains("Ш"), "Фонетический промпт называет звук")
    }

    // MARK: Feedback («светофор», без «неправильно»)

    func test_feedbackLine_hit_namesGrouping() {
        let line = FourthExtraPresenter.feedbackLine(tier: .hit, groupingLabel: "фрукты", extraReason: "это мебель")
        XCTAssertFalse(line.isEmpty)
        XCTAssertTrue(line.contains("фрукты"))
    }

    func test_feedbackLine_neverContainsWrongWord() {
        for tier in [FeedbackTier.hit, .almost, .retry] {
            let line = FourthExtraPresenter.feedbackLine(tier: tier, groupingLabel: "посуда", extraReason: "это животное")
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
            extraCardId: "c3",
            groupingLabel: "фрукты",
            extraReason: "это мебель",
            hintCardIds: [],
            showHint: false,
            askWhy: false,
            advancedToNextRound: true,
            isFinished: false,
            nextRound: makePhoneticRound(),
            nextRoundIndex: 1,
            correctCount: 1,
            totalRounds: 2
        ))
        XCTAssertEqual(display.answerVM?.feedback, .hit)
        XCTAssertFalse(display.answerVM?.lyalyaLine.isEmpty ?? true)
        XCTAssertNotNil(display.answerVM?.nextRound)
        XCTAssertNil(display.answerVM?.summary)
        XCTAssertEqual(display.answerVM?.groupingLabel, "фрукты")
    }

    func test_presentAnswer_retryWithHint_setsHintCardIds() async {
        let (sut, display) = makeSUT()
        await sut.presentAnswer(response: .init(
            feedback: .retry,
            extraCardId: "c3",
            groupingLabel: nil,
            extraReason: nil,
            hintCardIds: ["c0", "c1", "c2"],
            showHint: true,
            askWhy: false,
            advancedToNextRound: true,
            isFinished: false,
            nextRound: nil,
            nextRoundIndex: nil,
            correctCount: 0,
            totalRounds: 2
        ))
        XCTAssertEqual(display.answerVM?.feedback, .retry)
        XCTAssertEqual(Set(display.answerVM?.hintCardIds ?? []), ["c0", "c1", "c2"])
    }

    // MARK: Summary

    func test_presentAnswer_finished_buildsSummary_withCelebration() async {
        let (sut, display) = makeSUT()
        await sut.presentAnswer(response: .init(
            feedback: .hit,
            extraCardId: "c3",
            groupingLabel: "фрукты",
            extraReason: "это мебель",
            hintCardIds: [],
            showHint: false,
            askWhy: false,
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
            extraCardId: "c3",
            groupingLabel: nil,
            extraReason: nil,
            hintCardIds: [],
            showHint: true,
            askWhy: false,
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
        let vm = FourthExtraPresenter.makeRoundVM(makeSemanticRound(), index: 2, total: 10)
        XCTAssertFalse(vm.progressLabel.isEmpty)
        XCTAssertEqual(vm.progressFraction, 0.3, accuracy: 0.0001)
        XCTAssertFalse(vm.accessibilityLabel.isEmpty)
        XCTAssertEqual(vm.cards.count, 4)
    }
}
