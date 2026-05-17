@testable import HappySpeech
import PencilKit
import XCTest

// MARK: - HandwritingRecognitionWorkerTests
//
// Phase 2.7 v25 — покрытие HandwritingRecognitionWorker.
//
// Worker распознаёт рукописные буквы из PKDrawing через Vision.
// Vision-распознавание само по себе детерминированно не тестируется в unit
// (зависит от ML-модели), но guard-ветви тестируются полностью:
//   - пустой PKDrawing → nil (нет штрихов)
//   - слишком маленький рисунок → nil (bounds < 10pt)
//   - крупный осмысленный рисунок → не падает, возвращает String? или nil

final class HandwritingRecognitionWorkerTests: XCTestCase {

    private var sut: HandwritingRecognitionWorker!

    override func setUp() {
        super.setUp()
        sut = HandwritingRecognitionWorker()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Пустой рисунок

    func test_recognizeLetter_emptyDrawing_returnsNil() async {
        let result = await sut.recognizeLetter(from: PKDrawing())
        XCTAssertNil(result)
    }

    // MARK: - Слишком маленький рисунок

    func test_recognizeLetter_tinyStroke_returnsNil() async {
        // Один штрих в крошечной области — после inset bounds всё равно мал.
        let tinyStroke = makeStroke(points: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 1)
        ])
        let drawing = PKDrawing(strokes: [tinyStroke])
        let result = await sut.recognizeLetter(from: drawing)
        XCTAssertNil(result)
    }

    // MARK: - Крупный рисунок: не падает

    func test_recognizeLetter_largeStroke_doesNotCrash() async {
        // Крупный осмысленный штрих — Vision-запрос отрабатывает без краша.
        // Результат может быть nil (одиночный штрих — не буква), но не crash.
        let largeStroke = makeStroke(points: [
            CGPoint(x: 20, y: 20),
            CGPoint(x: 120, y: 20),
            CGPoint(x: 120, y: 220),
            CGPoint(x: 20, y: 220),
            CGPoint(x: 20, y: 20)
        ])
        let drawing = PKDrawing(strokes: [largeStroke])
        let result = await sut.recognizeLetter(from: drawing)
        // Распознанная буква (если есть) — ровно 1 символ.
        if let letter = result {
            XCTAssertEqual(letter.count, 1)
        }
    }

    // MARK: - Helpers

    private func makeStroke(points: [CGPoint]) -> PKStroke {
        let strokePoints = points.map { point in
            PKStrokePoint(
                location: point,
                timeOffset: 0,
                size: CGSize(width: 4, height: 4),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: 0
            )
        }
        let path = PKStrokePath(controlPoints: strokePoints, creationDate: Date())
        return PKStroke(ink: PKInk(.pen, color: .black), path: path)
    }
}
