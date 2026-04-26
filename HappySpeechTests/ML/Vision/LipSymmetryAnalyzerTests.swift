import XCTest

@testable import HappySpeech

// MARK: - LipSymmetryAnalyzerTests

final class LipSymmetryAnalyzerTests: XCTestCase {

    // MARK: - Test 1: Идеально симметричные губы (центр = 0.5)

    func testPerfectSymmetryGivesScoreNearOne() {
        // Точки симметрично вокруг x = 0.5
        let pts = [
            CGPoint(x: 0.3, y: 0.5),
            CGPoint(x: 0.7, y: 0.5),
            CGPoint(x: 0.4, y: 0.55),
            CGPoint(x: 0.6, y: 0.55),
            CGPoint(x: 0.5, y: 0.6)
        ]
        let result = LipSymmetryAnalyzer.analyze(mouthPoints: pts)
        XCTAssertGreaterThanOrEqual(result.symmetryScore, 0.9,
            "Идеально центрированные губы должны давать symmetryScore >= 0.9")
    }

    // MARK: - Test 2: Смещённые губы → низкий score

    func testAsymmetricLipsGiveLowScore() {
        // Губы смещены вправо (centerX ≈ 0.75)
        let pts = [
            CGPoint(x: 0.6, y: 0.5),
            CGPoint(x: 0.9, y: 0.5),
            CGPoint(x: 0.7, y: 0.55),
            CGPoint(x: 0.8, y: 0.45)
        ]
        let result = LipSymmetryAnalyzer.analyze(mouthPoints: pts)
        XCTAssertLessThan(result.symmetryScore, 0.5,
            "Сильно смещённые губы должны давать symmetryScore < 0.5")
    }

    // MARK: - Test 3: Рот открыт (mouthOpenRatio > 0.15)

    func testOpenMouthDetectedCorrectly() {
        // Высота >> ширина / 7 → открыт
        let pts = [
            CGPoint(x: 0.3, y: 0.4),
            CGPoint(x: 0.7, y: 0.4),
            CGPoint(x: 0.3, y: 0.7),  // высота 0.3, ширина 0.4 → ratio = 0.75 > 0.15
            CGPoint(x: 0.7, y: 0.7)
        ]
        let result = LipSymmetryAnalyzer.analyze(mouthPoints: pts)
        XCTAssertTrue(result.isOpen, "Рот с mouthOpenRatio > 0.15 должен определяться как открытый")
        XCTAssertGreaterThan(result.mouthOpenRatio, 0.15)
    }

    // MARK: - Test 4: Рот закрыт (плоская линия)

    func testClosedMouthNotDetectedAsOpen() {
        // Все точки на одной горизонтальной линии → height ≈ 0
        let pts = [
            CGPoint(x: 0.3, y: 0.5),
            CGPoint(x: 0.5, y: 0.5),
            CGPoint(x: 0.7, y: 0.5)
        ]
        let result = LipSymmetryAnalyzer.analyze(mouthPoints: pts)
        XCTAssertFalse(result.isOpen, "Горизонтальная линия не должна определяться как открытый рот")
        XCTAssertLessThanOrEqual(result.mouthOpenRatio, 0.15)
    }

    // MARK: - Test 5: Слишком мало точек → fallback (не краш)

    func testInsufficientPointsReturnsFallback() {
        let result = LipSymmetryAnalyzer.analyze(mouthPoints: [CGPoint(x: 0.5, y: 0.5)])
        // Fallback: symmetryScore = 0.5
        XCTAssertEqual(result.symmetryScore, 0.5, accuracy: 0.01,
            "С < 4 точками должен вернуться fallback 0.5")
        XCTAssertFalse(result.hasHypotonia, "Fallback не должен детектировать гипотонию")
    }

    // MARK: - Test 6: Гипотония — большой вертикальный перепад уголков

    func testHypotomiaDetectedWhenCornersAreVerticallyAsymmetric() {
        // Левый уголок y=0.5, правый y=0.6 — перепад 0.1 > threshold 0.04
        let pts = [
            CGPoint(x: 0.2, y: 0.5),   // левый угол
            CGPoint(x: 0.8, y: 0.6),   // правый угол опущен
            CGPoint(x: 0.4, y: 0.52),
            CGPoint(x: 0.6, y: 0.57)
        ]
        let result = LipSymmetryAnalyzer.analyze(mouthPoints: pts)
        XCTAssertTrue(result.hasHypotonia,
            "Большой вертикальный перепад уголков должен детектироваться как гипотония")
        XCTAssertGreaterThan(result.cornerVerticalAsymmetry, 0.04)
    }

    // MARK: - Test 7: FaceLandmarks76 перегрузка не крашится

    func testAnalyzeLandmarks76Overload() {
        let outerLips = [
            CGPoint(x: 0.3, y: 0.5),
            CGPoint(x: 0.5, y: 0.45),
            CGPoint(x: 0.7, y: 0.5)
        ]
        let landmarks = FaceLandmarks76(
            outerLips: outerLips,
            innerLips: [CGPoint(x: 0.4, y: 0.52), CGPoint(x: 0.6, y: 0.52)],
            nose: [],
            noseCrest: [],
            leftEye: [],
            rightEye: [],
            leftEyebrow: [],
            rightEyebrow: [],
            jaw: [],
            medianLine: [],
            allPoints: outerLips,
            boundingBox: .zero,
            confidence: 0.9
        )
        let result = LipSymmetryAnalyzer.analyze(landmarks: landmarks)
        XCTAssertTrue(result.symmetryScore >= 0 && result.symmetryScore <= 1,
            "symmetryScore должен быть в диапазоне [0, 1]")
    }
}
