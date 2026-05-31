@testable import HappySpeech
import XCTest

@MainActor
private final class SpyDetectiveDisplay:
    ComprehensionDetectiveDisplayLogic, @unchecked Sendable {
    var startVM: ComprehensionDetectiveModels.Start.ViewModel?
    var pickVM: ComprehensionDetectiveModels.Pick.ViewModel?

    func displayStart(viewModel: ComprehensionDetectiveModels.Start.ViewModel) async {
        startVM = viewModel
    }
    func displayPick(viewModel: ComprehensionDetectiveModels.Pick.ViewModel) async {
        pickVM = viewModel
    }
}

@MainActor
private func makeItem(
    id: String = "i1",
    tier: GrammarTier = .simple,
    instruction: String = "Покажи мяч"
) -> DetectiveItem {
    let pictures = [
        DetectivePicture(id: "\(id)-p1", symbolName: "soccerball", label: "мяч"),
        DetectivePicture(id: "\(id)-p2", symbolName: "car.fill", label: "машина"),
        DetectivePicture(id: "\(id)-p3", symbolName: "leaf.fill", label: "лист"),
        DetectivePicture(id: "\(id)-p4", symbolName: "house.fill", label: "дом")
    ]
    return DetectiveItem(
        id: id, tier: tier, instruction: instruction,
        pictures: pictures, correctPictureId: pictures[0].id, minAge: 5
    )
}

@MainActor
private func makeRound(_ item: DetectiveItem, index: Int = 0) -> DetectiveRound {
    DetectiveRound(id: "\(item.id)#\(index)", item: item, shuffledPictures: item.pictures)
}

@MainActor
final class ComprehensionDetectivePresenterTests: XCTestCase {

    private func makeStartResponse(
        rounds: [DetectiveRound]? = nil,
        leadTier: GrammarTier = .simple
    ) -> ComprehensionDetectiveModels.Start.Response {
        let rs = rounds ?? [makeRound(makeItem())]
        return .init(rounds: rs, soundTarget: "понимание речи", childAge: 6, leadTier: leadTier)
    }

    private func makePickResponse(
        feedback: FeedbackTier,
        showHint: Bool = false,
        isFinished: Bool = false,
        nextRound: DetectiveRound? = nil,
        nextIndex: Int? = nil,
        correct: Int = 0,
        total: Int = 2
    ) -> ComprehensionDetectiveModels.Pick.Response {
        .init(
            feedback: feedback,
            pickedPictureId: "x",
            correctPictureId: "i1-p1",
            instruction: "Покажи мяч",
            showHint: showHint,
            replaySlowly: feedback != .hit,
            advancedToNextRound: feedback == .hit || feedback == .retry,
            isFinished: isFinished,
            nextRound: nextRound,
            nextRoundIndex: nextIndex,
            correctCount: correct,
            totalRounds: total
        )
    }

    // MARK: Start

    func test_presentStart_buildsFirstRoundVM() async {
        let spy = SpyDetectiveDisplay()
        let presenter = ComprehensionDetectivePresenter(displayLogic: spy)
        await presenter.presentStart(response: makeStartResponse())
        XCTAssertEqual(spy.startVM?.totalRounds, 1)
        XCTAssertEqual(spy.startVM?.firstRound.instruction, "Покажи мяч")
        XCTAssertEqual(spy.startVM?.firstRound.pictures.count, 4)
        XCTAssertEqual(spy.startVM?.firstRound.tier, .simple)
    }

    func test_presentStart_emptyRounds_noDisplay() async {
        let spy = SpyDetectiveDisplay()
        let presenter = ComprehensionDetectivePresenter(displayLogic: spy)
        await presenter.presentStart(response: makeStartResponse(rounds: []))
        XCTAssertNil(spy.startVM)
    }

    func test_presentStart_pictureA11yUsesLabels() async {
        let spy = SpyDetectiveDisplay()
        let presenter = ComprehensionDetectivePresenter(displayLogic: spy)
        await presenter.presentStart(response: makeStartResponse())
        let labels = spy.startVM?.firstRound.pictures.map(\.accessibilityLabel) ?? []
        XCTAssertTrue(labels.contains("мяч"))
        XCTAssertTrue(labels.contains("машина"))
    }

    // MARK: Pick

    func test_presentPick_hit_setsFeedbackAndNoHint() async {
        let spy = SpyDetectiveDisplay()
        let presenter = ComprehensionDetectivePresenter(displayLogic: spy)
        await presenter.presentPick(response: makePickResponse(feedback: .hit))
        XCTAssertEqual(spy.pickVM?.feedback, .hit)
        XCTAssertNil(spy.pickVM?.hintPictureId)
        XCTAssertFalse(spy.pickVM?.replaySlowly ?? true)
    }

    func test_presentPick_retryWithHint_revealsCorrectPicture() async {
        let spy = SpyDetectiveDisplay()
        let presenter = ComprehensionDetectivePresenter(displayLogic: spy)
        await presenter.presentPick(response: makePickResponse(feedback: .retry, showHint: true))
        XCTAssertEqual(spy.pickVM?.feedback, .retry)
        XCTAssertEqual(spy.pickVM?.hintPictureId, "i1-p1", "Подсказка подсвечивает правильную картинку")
    }

    func test_presentPick_almost_replaySlowly() async {
        let spy = SpyDetectiveDisplay()
        let presenter = ComprehensionDetectivePresenter(displayLogic: spy)
        await presenter.presentPick(response: makePickResponse(feedback: .almost))
        XCTAssertEqual(spy.pickVM?.feedback, .almost)
        XCTAssertNil(spy.pickVM?.hintPictureId, "Первый промах — без подсказки")
        XCTAssertTrue(spy.pickVM?.replaySlowly ?? false)
    }

    func test_presentPick_finished_buildsSummary() async {
        let spy = SpyDetectiveDisplay()
        let presenter = ComprehensionDetectivePresenter(displayLogic: spy)
        await presenter.presentPick(response: makePickResponse(
            feedback: .hit, isFinished: true, correct: 2, total: 2
        ))
        XCTAssertNotNil(spy.pickVM?.summary)
        XCTAssertEqual(spy.pickVM?.summary?.correctCount, 2)
        XCTAssertEqual(spy.pickVM?.summary?.totalRounds, 2)
        XCTAssertEqual(spy.pickVM?.summary?.accuracyFraction ?? 0, 1.0, accuracy: 0.001)
        XCTAssertTrue(spy.pickVM?.summary?.showCelebration ?? false, "100% → праздник")
    }

    func test_presentPick_finishedLowScore_noCelebration() async {
        let spy = SpyDetectiveDisplay()
        let presenter = ComprehensionDetectivePresenter(displayLogic: spy)
        await presenter.presentPick(response: makePickResponse(
            feedback: .retry, isFinished: true, correct: 1, total: 4
        ))
        XCTAssertEqual(spy.pickVM?.summary?.accuracyFraction ?? 1, 0.25, accuracy: 0.001)
        XCTAssertFalse(spy.pickVM?.summary?.showCelebration ?? true)
    }

    func test_presentPick_withNextRound_buildsNextVM() async {
        let spy = SpyDetectiveDisplay()
        let presenter = ComprehensionDetectivePresenter(displayLogic: spy)
        let next = makeRound(makeItem(id: "i2", tier: .doubleInstruction, instruction: "Сначала яблоко, потом кружку"), index: 1)
        await presenter.presentPick(response: makePickResponse(
            feedback: .hit, nextRound: next, nextIndex: 1, correct: 1, total: 2
        ))
        XCTAssertEqual(spy.pickVM?.nextRound?.instruction, "Сначала яблоко, потом кружку")
        XCTAssertEqual(spy.pickVM?.nextRound?.tier, .doubleInstruction)
    }

    // MARK: Feedback lines & helpers (pure)

    func test_feedbackLine_neverEmptyForAnyTier() {
        for tier in [FeedbackTier.hit, .almost, .retry] {
            XCTAssertFalse(ComprehensionDetectivePresenter.feedbackLine(tier: tier).isEmpty)
        }
    }

    func test_encouragement_thresholds() {
        XCTAssertFalse(ComprehensionDetectivePresenter.encouragement(for: 0.9).isEmpty)
        XCTAssertFalse(ComprehensionDetectivePresenter.encouragement(for: 0.6).isEmpty)
        XCTAssertFalse(ComprehensionDetectivePresenter.encouragement(for: 0.1).isEmpty)
    }

    func test_localized_returnsKeyIfMissing() {
        let result = ComprehensionDetectivePresenter.localized("missing.key.does.not.exist")
        XCTAssertEqual(result, "missing.key.does.not.exist")
    }
}
