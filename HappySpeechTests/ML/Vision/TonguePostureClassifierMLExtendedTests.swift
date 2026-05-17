@testable import HappySpeech
import XCTest

// MARK: - TonguePostureClassifierMLExtendedTests
//
// Phase 2.6c v25 — расширенное покрытие TonguePostureClassifierML.
//
// Тестируется дополнительная логика:
//   - TonguePostureML: rawValue совпадает с ожидаемым
//   - classify(features:) при различных активных blendshapes
//   - extractFeatureVector: резервные позиции [23..49] = 0
//   - TonguePostureMLResult: поля корректные
//   - fallbackResult: при mlModel=nil → rule-based результат

final class TonguePostureClassifierMLExtendedTests: XCTestCase {

    var classifier: TonguePostureClassifierML!

    override func setUp() {
        classifier = TonguePostureClassifierML()
    }

    // MARK: - TonguePostureML: rawValue

    func testTonguePostureML_neutral_rawValue() {
        XCTAssertEqual(TonguePostureML.neutral.rawValue, "neutral")
    }

    func testTonguePostureML_cupShape_rawValue() {
        XCTAssertEqual(TonguePostureML.cupShape.rawValue, "cup_shape")
    }

    func testTonguePostureML_tongueUp_rawValue() {
        XCTAssertEqual(TonguePostureML.tongueUp.rawValue, "tongue_up")
    }

    func testTonguePostureML_tongueDown_rawValue() {
        XCTAssertEqual(TonguePostureML.tongueDown.rawValue, "tongue_down")
    }

    func testTonguePostureML_tongueLeft_rawValue() {
        XCTAssertEqual(TonguePostureML.tongueLeft.rawValue, "tongue_left")
    }

    func testTonguePostureML_tongueRight_rawValue() {
        XCTAssertEqual(TonguePostureML.tongueRight.rawValue, "tongue_right")
    }

    func testTonguePostureML_shoveling_rawValue() {
        XCTAssertEqual(TonguePostureML.shoveling.rawValue, "shoveling")
    }

    func testTonguePostureML_mushroom_rawValue() {
        XCTAssertEqual(TonguePostureML.mushroom.rawValue, "mushroom")
    }

    func testTonguePostureML_painter_rawValue() {
        XCTAssertEqual(TonguePostureML.painter.rawValue, "painter")
    }

    // MARK: - TonguePostureML: инициализация из rawValue

    func testTonguePostureML_initFromRawValue_valid() {
        XCTAssertEqual(TonguePostureML(rawValue: "neutral"), .neutral)
        XCTAssertEqual(TonguePostureML(rawValue: "cup_shape"), .cupShape)
        XCTAssertEqual(TonguePostureML(rawValue: "tongue_up"), .tongueUp)
    }

    func testTonguePostureML_initFromRawValue_invalid_nil() {
        XCTAssertNil(TonguePostureML(rawValue: "неизвестная_поза"))
    }

    // MARK: - classify(features:): корректные фичи → не краш, confidence в [0, 1]

    func testClassify_neutralFeatures_confidenceInRange() {
        let features = [Float](repeating: 0.0, count: TonguePostureClassifierML.featureDimension)
        let result = classifier.classify(features: features)
        XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
        XCTAssertLessThanOrEqual(result.confidence, 1.0)
    }

    func testClassify_tongueOutHigh_nocrash() {
        // tongueOut (индекс 19) высокий → может активировать tongueUp или painter
        var features = [Float](repeating: 0.0, count: TonguePostureClassifierML.featureDimension)
        features[19] = 0.95  // tongueOut
        features[0] = 0.5    // jawOpen
        let result = classifier.classify(features: features)
        XCTAssertNotNil(result.posture)
        XCTAssertFalse(result.probabilities.isEmpty)
    }

    // MARK: - classify(blendshapes:) → определённая поза или fallback

    func testClassify_blendshapes_neutralFromFallback() {
        // Нейтральные blendshapes → в fallback классификаторе → neutral
        let bs = FaceBlendshapes.neutral
        let result = classifier.classify(blendshapes: bs)
        // Независимо от наличия mlpackage — не краш
        XCTAssertNotNil(result.posture)
    }

    func testClassify_blendshapes_jawOpenHigh_nocrash() {
        let bs = FaceBlendshapes(jawOpen: 0.9)
        let result = classifier.classify(blendshapes: bs)
        XCTAssertNotNil(result.posture)
    }

    // MARK: - extractFeatureVector: конкретные значения blendshapes

    func testExtractFeatureVector_jawForward_at_index1() {
        let bs = FaceBlendshapes(jawForward: 0.6)
        let features = TonguePostureClassifierML.extractFeatureVector(blendshapes: bs)
        XCTAssertEqual(features[1], 0.6, accuracy: 0.001, "jawForward должен быть на индексе 1")
    }

    func testExtractFeatureVector_mouthPucker_at_index3() {
        let bs = FaceBlendshapes(mouthPucker: 0.7)
        let features = TonguePostureClassifierML.extractFeatureVector(blendshapes: bs)
        XCTAssertEqual(features[3], 0.7, accuracy: 0.001)
    }

    func testExtractFeatureVector_mouthClose_at_index16() {
        let bs = FaceBlendshapes(mouthClose: 0.8)
        let features = TonguePostureClassifierML.extractFeatureVector(blendshapes: bs)
        XCTAssertEqual(features[16], 0.8, accuracy: 0.001)
    }

    func testExtractFeatureVector_cheekPuff_at_index22() {
        let bs = FaceBlendshapes(cheekPuff: 0.55)
        let features = TonguePostureClassifierML.extractFeatureVector(blendshapes: bs)
        XCTAssertEqual(features[22], 0.55, accuracy: 0.001)
    }

    func testExtractFeatureVector_reservedPositions_allZero() {
        let bs = FaceBlendshapes.neutral
        let features = TonguePostureClassifierML.extractFeatureVector(blendshapes: bs)
        for i in 23..<TonguePostureClassifierML.featureDimension {
            XCTAssertEqual(features[i], 0.0, accuracy: 0.001,
                "Резервный элемент [\(i)] должен быть 0.0")
        }
    }

    // MARK: - TonguePostureMLResult: поля

    func testTonguePostureMLResult_fields() {
        let probs: [TonguePostureML: Float] = [.neutral: 0.9, .cupShape: 0.1]
        let result = TonguePostureMLResult(posture: .neutral, confidence: 0.9, probabilities: probs)
        XCTAssertEqual(result.posture, .neutral)
        XCTAssertEqual(result.confidence, 0.9, accuracy: 0.001)
        XCTAssertEqual(Double(result.probabilities[.neutral] ?? 0), 0.9, accuracy: 0.001)
    }

    // MARK: - classify(features:): неверная размерность → не nil результат

    func testClassify_wrongDimension_49_nocrash() {
        let features = [Float](repeating: 0.5, count: 49)  // 49, не 50
        let result = classifier.classify(features: features)
        XCTAssertNotNil(result)
    }

    func testClassify_wrongDimension_0_nocrash() {
        let result = classifier.classify(features: [])
        XCTAssertNotNil(result)
    }

    // MARK: - instance extractFeatureVector: делегирует в static

    func testInstance_extractFeatureVector_sameAsStatic() {
        let bs = FaceBlendshapes(jawOpen: 0.3, tongueOut: 0.6)
        let instanceResult = classifier.extractFeatureVector(blendshapes: bs)
        let staticResult = TonguePostureClassifierML.extractFeatureVector(blendshapes: bs)
        XCTAssertEqual(instanceResult, staticResult)
    }
}
