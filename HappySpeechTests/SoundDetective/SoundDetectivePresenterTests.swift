@testable import HappySpeech
import XCTest

// MARK: - Spy DisplayLogic

@MainActor
private final class SpyDetectiveDisplay: SoundDetectiveDisplayLogic, @unchecked Sendable {
    var startVM: SoundDetectiveModels.Start.ViewModel?
    var answerVM: SoundDetectiveModels.Answer.ViewModel?

    func displayStart(viewModel: SoundDetectiveModels.Start.ViewModel) async {
        startVM = viewModel
    }
    func displayAnswer(viewModel: SoundDetectiveModels.Answer.ViewModel) async {
        answerVM = viewModel
    }
}

// MARK: - Helpers

@MainActor
private func makeItem(
    position: SoundZone = .start,
    sound: String = "С",
    word: String = "сок"
) -> SoundDetectiveItem {
    .init(
        id: "i", word: word, imageAsset: "word_sok",
        targetSound: sound, soundFamily: "свистящие",
        position: position, sounds: ["с", "о", "к"],
        difficulty: 1, minLevel: .binary
    )
}

// MARK: - Presenter Tests

@MainActor
final class SoundDetectivePresenterTests: XCTestCase {

    private func makeSUT() -> (SoundDetectivePresenter, SpyDetectiveDisplay) {
        let display = SpyDetectiveDisplay()
        let sut = SoundDetectivePresenter(displayLogic: display)
        return (sut, display)
    }

    // MARK: Start

    func test_presentStart_buildsViewModelWithFirstRound() async {
        let (sut, display) = makeSUT()
        let rounds = [
            SoundDetectiveRound(id: "r1", item: makeItem(position: .start), level: .ternary),
            SoundDetectiveRound(id: "r2", item: makeItem(position: .end, word: "нос"), level: .ternary)
        ]
        await sut.presentStart(response: .init(rounds: rounds, targetSound: "С", level: .ternary))
        XCTAssertNotNil(display.startVM)
        XCTAssertEqual(display.startVM?.totalRounds, 2)
        XCTAssertEqual(display.startVM?.firstRound.wordText, "сок")
        XCTAssertFalse(display.startVM?.firstRound.promptLyalya.isEmpty ?? true)
        XCTAssertEqual(display.startVM?.firstRound.imageAsset, "word_sok")
    }

    func test_presentStart_emptyRounds_doesNotCrashOrDisplay() async {
        let (sut, display) = makeSUT()
        await sut.presentStart(response: .init(rounds: [], targetSound: "С", level: .binary))
        XCTAssertNil(display.startVM)
    }

    // MARK: Zones mapping per level

    func test_binaryRound_hasTwoZones_startAndEnd() async {
        let (sut, display) = makeSUT()
        let round = SoundDetectiveRound(id: "r1", item: makeItem(), level: .binary)
        await sut.presentStart(response: .init(rounds: [round], targetSound: "С", level: .binary))
        let zones = display.startVM?.firstRound.zones ?? []
        XCTAssertEqual(zones.count, 2)
        XCTAssertEqual(zones.map(\.id), [.start, .end])
    }

    func test_ternaryRound_hasThreeZones() async {
        let (sut, display) = makeSUT()
        let round = SoundDetectiveRound(id: "r1", item: makeItem(), level: .ternary)
        await sut.presentStart(response: .init(rounds: [round], targetSound: "С", level: .ternary))
        let zones = display.startVM?.firstRound.zones ?? []
        XCTAssertEqual(zones.map(\.id), [.start, .middle, .end])
    }

    func test_withAbsentRound_hasFourZones_includingAbsent() async {
        let (sut, display) = makeSUT()
        let round = SoundDetectiveRound(id: "r1", item: makeItem(), level: .withAbsent)
        await sut.presentStart(response: .init(rounds: [round], targetSound: "С", level: .withAbsent))
        let zones = display.startVM?.firstRound.zones ?? []
        XCTAssertEqual(zones.map(\.id), [.start, .middle, .end, .absent])
    }

    func test_zoneColorHints_areMnemonicNotEvaluative() {
        XCTAssertEqual(SoundDetectivePresenter.colorHint(.start), .start)
        XCTAssertEqual(SoundDetectivePresenter.colorHint(.middle), .middle)
        XCTAssertEqual(SoundDetectivePresenter.colorHint(.end), .end)
        XCTAssertEqual(SoundDetectivePresenter.colorHint(.absent), .absent)
    }

    func test_zoneLabels_areNonEmptyAndDistinct() {
        let labels = SoundZone.allCases.map(SoundDetectivePresenter.zoneLabel)
        XCTAssertTrue(labels.allSatisfy { !$0.isEmpty })
        XCTAssertEqual(Set(labels).count, labels.count)
    }

    // MARK: Feedback («светофор», без «неправильно»)

    func test_feedbackLine_hit_namesZone() {
        let line = SoundDetectivePresenter.feedbackLine(tier: .hit, correctZone: .start)
        XCTAssertFalse(line.isEmpty)
        // На попадание реплика содержит подпись зоны.
        XCTAssertTrue(line.contains(SoundDetectivePresenter.zoneLabel(.start)))
    }

    func test_feedbackLine_neverContainsWrongWord() {
        for tier in [FeedbackTier.hit, .almost, .retry] {
            let line = SoundDetectivePresenter.feedbackLine(tier: tier, correctZone: .middle)
            XCTAssertFalse(line.lowercased().contains("неправильно"),
                           "Реплика \(tier) не должна содержать «неправильно»")
            XCTAssertFalse(line.lowercased().contains("ошибк"),
                           "Реплика \(tier) не должна содержать «ошибка»")
        }
    }

    func test_presentAnswer_hit_setsFeedbackAndNext() async {
        let (sut, display) = makeSUT()
        let next = SoundDetectiveRound(id: "r2", item: makeItem(position: .end), level: .ternary)
        await sut.presentAnswer(response: .init(
            feedback: .hit,
            correctZone: .start,
            highlightSoundIndex: 0,
            showHint: false,
            replayWithEmphasis: false,
            advancedToNextRound: true,
            isFinished: false,
            nextRound: next,
            nextRoundIndex: 1,
            correctCount: 1,
            totalRounds: 2
        ))
        XCTAssertEqual(display.answerVM?.feedback, .hit)
        XCTAssertFalse(display.answerVM?.lyalyaLine.isEmpty ?? true)
        XCTAssertNotNil(display.answerVM?.nextRound)
        XCTAssertNil(display.answerVM?.summary)
        XCTAssertNil(display.answerVM?.hintZone)
    }

    func test_presentAnswer_retryWithHint_setsHintZone() async {
        let (sut, display) = makeSUT()
        await sut.presentAnswer(response: .init(
            feedback: .retry,
            correctZone: .middle,
            highlightSoundIndex: nil,
            showHint: true,
            replayWithEmphasis: true,
            advancedToNextRound: true,
            isFinished: false,
            nextRound: nil,
            nextRoundIndex: nil,
            correctCount: 0,
            totalRounds: 2
        ))
        XCTAssertEqual(display.answerVM?.feedback, .retry)
        XCTAssertEqual(display.answerVM?.hintZone, .middle)
    }

    func test_presentAnswer_almost_noHintZone() async {
        let (sut, display) = makeSUT()
        await sut.presentAnswer(response: .init(
            feedback: .almost,
            correctZone: .end,
            highlightSoundIndex: nil,
            showHint: false,
            replayWithEmphasis: true,
            advancedToNextRound: false,
            isFinished: false,
            nextRound: nil,
            nextRoundIndex: nil,
            correctCount: 0,
            totalRounds: 2
        ))
        XCTAssertEqual(display.answerVM?.feedback, .almost)
        XCTAssertNil(display.answerVM?.hintZone)
        XCTAssertTrue(display.answerVM?.replayWithEmphasis ?? false)
    }

    // MARK: Summary

    func test_presentAnswer_finished_buildsSummary_withCelebration() async {
        let (sut, display) = makeSUT()
        await sut.presentAnswer(response: .init(
            feedback: .hit,
            correctZone: .start,
            highlightSoundIndex: 0,
            showHint: false,
            replayWithEmphasis: false,
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
            correctZone: .end,
            highlightSoundIndex: nil,
            showHint: true,
            replayWithEmphasis: true,
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
        let round = SoundDetectiveRound(id: "r", item: makeItem(), level: .ternary)
        let vm = SoundDetectivePresenter.makeRoundVM(round, index: 2, total: 10)
        XCTAssertFalse(vm.progressLabel.isEmpty)
        XCTAssertEqual(vm.progressFraction, 0.3, accuracy: 0.0001)
        XCTAssertFalse(vm.accessibilityLabel.isEmpty)
        XCTAssertEqual(vm.audioWordId, "i")
    }
}
