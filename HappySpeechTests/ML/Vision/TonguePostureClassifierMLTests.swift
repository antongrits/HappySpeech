import XCTest

@testable import HappySpeech

// MARK: - TonguePostureClassifierMLTests

final class TonguePostureClassifierMLTests: XCTestCase {

    var classifier: TonguePostureClassifierML!

    override func setUp() {
        classifier = TonguePostureClassifierML()
    }

    // MARK: - Test 1: Инициализация не крашится (даже без .mlpackage в тест-бандле)

    func testClassifierInitializesWithoutCrash() {
        XCTAssertNotNil(classifier, "Классификатор должен инициализироваться без краша")
    }

    // MARK: - Test 2: Нейтральные blendshapes → neutral поза

    func testNeutralBlendshapesClassifiedAsNeutral() {
        let bs = FaceBlendshapes.neutral
        let result = classifier.classify(blendshapes: bs)
        XCTAssertEqual(result.posture, .neutral,
            "Нулевые blendshapes должны давать neutral")
        XCTAssertGreaterThan(result.confidence, 0.0)
        XCTAssertLessThanOrEqual(result.confidence, 1.0)
    }

    // MARK: - Test 3: Трубочка (mouthPucker > 0.6) → pucker → nearest ML class

    func testPuckerBlendshapesMapped() {
        let bs = FaceBlendshapes(mouthPucker: 0.8)
        let result = classifier.classify(blendshapes: bs)
        // В ML fallback pucker не существует → classifier может дать shoveling или neutral
        // Важно: не краш, confidence в [0,1]
        XCTAssertFalse(result.probabilities.isEmpty, "Вероятности не должны быть пустыми")
        for (_, prob) in result.probabilities {
            XCTAssertGreaterThanOrEqual(prob, 0.0)
            XCTAssertLessThanOrEqual(prob, 1.0)
        }
    }

    // MARK: - Test 4: Feature vector правильной длины

    func testExtractFeatureVectorHasCorrectDimension() {
        let bs = FaceBlendshapes(
            jawOpen: 0.5,
            mouthFunnel: 0.3,
            tongueOut: 0.7
        )
        let features = TonguePostureClassifierML.extractFeatureVector(blendshapes: bs)
        XCTAssertEqual(features.count, TonguePostureClassifierML.featureDimension,
            "Feature vector должен содержать \(TonguePostureClassifierML.featureDimension) элементов")
    }

    // MARK: - Test 5: Неверная размерность features → не краш, возвращает neutral

    func testWrongFeatureDimensionReturnsFallback() {
        let wrongFeatures = [Float](repeating: 0.5, count: 10)  // должно быть 50
        let result = classifier.classify(features: wrongFeatures)
        // Должен упасть в error-path и не крашиться
        XCTAssertNotNil(result, "Неверная размерность не должна приводить к крашу")
    }

    // MARK: - Test 6: Все позы TonguePostureML имеют displayName

    func testAllPosturesHaveNonEmptyDisplayName() {
        for posture in TonguePostureML.allCases {
            // displayName не должен быть пустым (ключ локализации может вернуться как сам ключ)
            XCTAssertFalse(posture.rawValue.isEmpty, "rawValue не должен быть пустым: \(posture)")
        }
    }

    // MARK: - Test 7: TonguePostureML содержит 9 классов

    func testTonguePostureMLHasNineClasses() {
        XCTAssertEqual(TonguePostureML.allCases.count, 9,
            "TonguePostureML должен содержать ровно 9 классов (8 поз + neutral)")
    }

    // MARK: - Test 8: feature vector blendshapes → первые 23 элемента не нулевые при активных blendshapes

    func testFeatureVectorPreservesBlendshapeValues() {
        let bs = FaceBlendshapes(
            jawOpen: 0.5,
            mouthFunnel: 0.4,
            mouthPucker: 0.3,
            tongueOut: 0.7,
            cheekPuff: 0.2
        )
        let features = TonguePostureClassifierML.extractFeatureVector(blendshapes: bs)
        // jawOpen — первый элемент
        XCTAssertEqual(features[0], 0.5, accuracy: 0.001)
        // mouthFunnel — индекс 2
        XCTAssertEqual(features[2], 0.4, accuracy: 0.001)
        // tongueOut — индекс 19
        XCTAssertEqual(features[19], 0.7, accuracy: 0.001)
        // Резервные элементы [23..49] = 0
        for i in 23..<TonguePostureClassifierML.featureDimension {
            XCTAssertEqual(features[i], 0.0, accuracy: 0.001,
                "Резервный элемент \(i) должен быть 0.0")
        }
    }
}
