@testable import HappySpeech
import XCTest

// MARK: - LetterPaintingFunInteractorTests
//
// LetterPaintingFunInteractor is a thin VIP MVP variant (@Observable). It manages
// a small painting canvas: selectLetter switches the target letter and clears the
// canvas, selectColor changes the active brush, appendStroke records a stroke with
// the active colour (ignoring empty point arrays), and clear wipes strokes. Tests
// cover all mutations, the empty-stroke guard and the colour-of-record behaviour.
// (PaintColor.color/.label maps are purely presentational — intentionally skipped.)

@MainActor
final class LetterPaintingFunInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> LetterPaintingFunInteractor {
        LetterPaintingFunInteractor(childId: childId)
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-paint")
        XCTAssertEqual(sut.childId, "kid-paint")
    }

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_noStrokes() {
        let sut = makeSUT()
        XCTAssertTrue(sut.state.strokes.isEmpty)
    }

    func test_initialState_defaultLetterAndColor() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.currentLetter, "Р")
        XCTAssertEqual(sut.state.currentColor, .coral)
    }

    // MARK: - selectLetter

    func test_selectLetter_changesCurrentLetter() {
        let sut = makeSUT()
        sut.selectLetter("Ш")
        XCTAssertEqual(sut.state.currentLetter, "Ш")
    }

    func test_selectLetter_clearsExistingStrokes() {
        let sut = makeSUT()
        sut.appendStroke([CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)])
        XCTAssertFalse(sut.state.strokes.isEmpty)
        sut.selectLetter("С")
        XCTAssertTrue(sut.state.strokes.isEmpty)
    }

    func test_selectLetter_keepsCurrentColor() {
        let sut = makeSUT()
        sut.selectColor(.mint)
        sut.selectLetter("К")
        XCTAssertEqual(sut.state.currentColor, .mint)
    }

    // MARK: - selectColor

    func test_selectColor_changesCurrentColor() {
        let sut = makeSUT()
        sut.selectColor(.sky)
        XCTAssertEqual(sut.state.currentColor, .sky)
    }

    func test_selectColor_doesNotClearStrokes() {
        let sut = makeSUT()
        sut.appendStroke([CGPoint(x: 2, y: 2)])
        sut.selectColor(.lilac)
        XCTAssertEqual(sut.state.strokes.count, 1)
    }

    // MARK: - appendStroke

    func test_appendStroke_addsStroke() {
        let sut = makeSUT()
        sut.appendStroke([CGPoint(x: 0, y: 0), CGPoint(x: 5, y: 5)])
        XCTAssertEqual(sut.state.strokes.count, 1)
        XCTAssertEqual(sut.state.strokes[0].points.count, 2)
    }

    func test_appendStroke_usesCurrentColor() {
        let sut = makeSUT()
        sut.selectColor(.butter)
        sut.appendStroke([CGPoint(x: 1, y: 1)])
        XCTAssertEqual(sut.state.strokes.last?.color, .butter)
    }

    func test_appendStroke_emptyPoints_ignored() {
        let sut = makeSUT()
        sut.appendStroke([])
        XCTAssertTrue(sut.state.strokes.isEmpty)
    }

    func test_appendStroke_multipleStrokesAccumulate() {
        let sut = makeSUT()
        sut.appendStroke([CGPoint(x: 0, y: 0)])
        sut.selectColor(.mint)
        sut.appendStroke([CGPoint(x: 1, y: 1)])
        XCTAssertEqual(sut.state.strokes.count, 2)
        XCTAssertEqual(sut.state.strokes[0].color, .coral)
        XCTAssertEqual(sut.state.strokes[1].color, .mint)
    }

    func test_appendStroke_strokesHaveUniqueIds() {
        let sut = makeSUT()
        sut.appendStroke([CGPoint(x: 0, y: 0)])
        sut.appendStroke([CGPoint(x: 1, y: 1)])
        XCTAssertNotEqual(sut.state.strokes[0].id, sut.state.strokes[1].id)
    }

    // MARK: - clear

    func test_clear_removesAllStrokes() {
        let sut = makeSUT()
        sut.appendStroke([CGPoint(x: 0, y: 0)])
        sut.appendStroke([CGPoint(x: 1, y: 1)])
        sut.clear()
        XCTAssertTrue(sut.state.strokes.isEmpty)
    }

    func test_clear_keepsLetterAndColor() {
        let sut = makeSUT()
        sut.selectLetter("Л")
        sut.selectColor(.sky)
        sut.appendStroke([CGPoint(x: 0, y: 0)])
        sut.clear()
        XCTAssertEqual(sut.state.currentLetter, "Л")
        XCTAssertEqual(sut.state.currentColor, .sky)
    }

    // MARK: - availableLetters

    func test_availableLetters_nonEmptyAndUnique() {
        let letters = LetterPaintingFunModels.availableLetters
        XCTAssertFalse(letters.isEmpty)
        XCTAssertEqual(Set(letters).count, letters.count)
    }
}
