@testable import HappySpeech
import XCTest

// MARK: - LetterTracePresenterTests
//
// Verifies the non-trivial Response → ViewModel mapping in the kid
// "trace with your finger" presenter:
//   - Load: totalCount preserved; firstItem present iff items non-empty
//   - Load: prompt key differs between letter & syllable item kinds
//   - Load: progress text non-empty
//   - Advance: item nil when no nextItem; position/total propagated to progress
//   - Score: band → feedback text / symbol / success flag mapping
//     (excellent ≥ 75, good 50..<75, tryAgain < 50)
//   - Score: percent passthrough + clamp boundaries

@MainActor
final class LetterTracePresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: LetterTraceDisplayLogic {
        var loadVM: LetterTraceModels.Load.ViewModel?
        var advanceVM: LetterTraceModels.Advance.ViewModel?
        var scoreVM: LetterTraceModels.Score.ViewModel?

        func displayLoad(viewModel: LetterTraceModels.Load.ViewModel) async { loadVM = viewModel }
        func displayAdvance(viewModel: LetterTraceModels.Advance.ViewModel) async { advanceVM = viewModel }
        func displayScore(viewModel: LetterTraceModels.Score.ViewModel) async { scoreVM = viewModel }
    }

    private func makeSUT() -> (LetterTracePresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = LetterTracePresenter(displayLogic: spy)
        return (presenter, spy)
    }

    private func item(
        _ id: String, kind: TraceItemKind = .letter, symbol: String = "А"
    ) -> TraceItem {
        TraceItem(id: id, kind: kind, symbol: symbol, strokes: [[TracePoint(x: 0, y: 0)]])
    }

    // MARK: - Load

    func test_load_totalCountAndFirstItem() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(items: [item("i1"), item("i2"), item("i3")]))
        XCTAssertEqual(spy.loadVM?.totalCount, 3)
        XCTAssertEqual(spy.loadVM?.firstItem?.id, "i1")
        XCTAssertFalse(spy.loadVM?.firstItem?.progressText.isEmpty ?? true)
    }

    func test_load_emptyItems_firstItemNil() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(items: []))
        XCTAssertEqual(spy.loadVM?.totalCount, 0)
        XCTAssertNil(spy.loadVM?.firstItem ?? nil)
    }

    func test_load_letterVsSyllable_promptKeyDiffers() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(items: [item("l", kind: .letter, symbol: "Б")]))
        let letterPrompt = spy.loadVM?.firstItem?.promptText

        await sut.presentLoad(response: .init(items: [item("s", kind: .syllable, symbol: "БА")]))
        let syllablePrompt = spy.loadVM?.firstItem?.promptText

        XCTAssertNotNil(letterPrompt)
        XCTAssertNotNil(syllablePrompt)
        XCTAssertNotEqual(letterPrompt, syllablePrompt, "Буква и слог используют разные шаблоны подсказки")
    }

    func test_load_referenceStrokesCarried() async {
        let (sut, spy) = makeSUT()
        let strokes = [[TracePoint(x: 0.1, y: 0.2), TracePoint(x: 0.3, y: 0.4)]]
        let custom = TraceItem(id: "c", kind: .letter, symbol: "В", strokes: strokes)
        await sut.presentLoad(response: .init(items: [custom]))
        XCTAssertEqual(spy.loadVM?.firstItem?.referenceStrokes, strokes)
    }

    // MARK: - Advance

    func test_advance_withNextItem_mapsItem() async {
        let (sut, spy) = makeSUT()
        await sut.presentAdvance(response: .init(nextItem: item("n1"), position: 2, totalCount: 5))
        XCTAssertEqual(spy.advanceVM?.item?.id, "n1")
        XCTAssertFalse(spy.advanceVM?.item?.progressText.isEmpty ?? true)
    }

    func test_advance_noNextItem_nilItem() async {
        let (sut, spy) = makeSUT()
        await sut.presentAdvance(response: .init(nextItem: nil, position: 5, totalCount: 5))
        XCTAssertNil(spy.advanceVM?.item ?? nil)
    }

    // MARK: - Score band mapping

    private func score(_ similarity: Double) -> LetterTraceModels.Score.Response {
        .init(itemId: "x", score: TraceScore(similarity: similarity))
    }

    func test_score_excellentBand() async {
        let (sut, spy) = makeSUT()
        await sut.presentScore(response: score(0.90)) // 90% → excellent
        XCTAssertEqual(spy.scoreVM?.isSuccess, true)
        XCTAssertEqual(spy.scoreVM?.bandSymbol, "checkmark.seal.fill")
        XCTAssertEqual(spy.scoreVM?.percent, 90)
    }

    func test_score_goodBand() async {
        let (sut, spy) = makeSUT()
        await sut.presentScore(response: score(0.60)) // 60% → good
        XCTAssertEqual(spy.scoreVM?.isSuccess, true)
        XCTAssertEqual(spy.scoreVM?.bandSymbol, "checkmark.circle.fill")
    }

    func test_score_tryAgainBand() async {
        let (sut, spy) = makeSUT()
        await sut.presentScore(response: score(0.20)) // 20% → tryAgain
        XCTAssertEqual(spy.scoreVM?.isSuccess, false)
        XCTAssertEqual(spy.scoreVM?.bandSymbol, "arrow.counterclockwise.circle.fill")
    }

    func test_score_bandBoundary75_isExcellent() async {
        let (sut, spy) = makeSUT()
        await sut.presentScore(response: score(0.75))
        XCTAssertEqual(spy.scoreVM?.bandSymbol, "checkmark.seal.fill")
    }

    func test_score_bandBoundary50_isGood() async {
        let (sut, spy) = makeSUT()
        await sut.presentScore(response: score(0.50))
        XCTAssertEqual(spy.scoreVM?.bandSymbol, "checkmark.circle.fill")
        XCTAssertEqual(spy.scoreVM?.isSuccess, true)
    }

    func test_score_percentClampedToHundred() async {
        let (sut, spy) = makeSUT()
        await sut.presentScore(response: score(1.5)) // similarity clamps to 1.0 → 100%
        XCTAssertEqual(spy.scoreVM?.percent, 100)
    }

    func test_score_feedbackTextNonEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentScore(response: score(0.30))
        XCTAssertFalse(spy.scoreVM?.feedbackText.isEmpty ?? true)
    }
}
