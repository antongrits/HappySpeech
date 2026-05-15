import Foundation
import XCTest
@testable import HappySpeech

// MARK: - EmotionDetectionServiceTests
//
// Тесты MockEmotionDetectionService + LiveEmotionDetectionService.
// Live: модель EmotionDetection.mlpackage отсутствует в тестовом бандле →
// analyze возвращает neutralResult — проверяется детерминированный fallback (COPPA-safe).

final class EmotionDetectionServiceTests: XCTestCase {

    // MARK: - DetectedEmotion

    func testDetectedEmotionAllCases() {
        XCTAssertEqual(DetectedEmotion.allCases.count, 4)
        XCTAssertEqual(Set(DetectedEmotion.allCases.map(\.rawValue)),
                       ["happy", "sad", "frustrated", "neutral"])
    }

    func testDetectedEmotionDisplayNamesNotEmpty() {
        for emotion in DetectedEmotion.allCases {
            XCTAssertFalse(emotion.displayName.isEmpty, "\(emotion) без displayName")
        }
    }

    // MARK: - MockEmotionDetectionService

    func testMockDefaultReturnsHappy() async {
        let mock = MockEmotionDetectionService()
        let result = await mock.analyze(pcmData: Data())
        XCTAssertEqual(result.emotion, .happy)
        XCTAssertEqual(result.confidence, 0.95, accuracy: 0.001)
    }

    func testMockReturnsConfiguredEmotion() async {
        let mock = MockEmotionDetectionService(emotion: .frustrated, confidence: 0.8)
        let result = await mock.analyze(pcmData: Data([1, 2, 3]))
        XCTAssertEqual(result.emotion, .frustrated)
        XCTAssertEqual(result.confidence, 0.8, accuracy: 0.001)
    }

    func testMockScoresSumToOne() async {
        let mock = MockEmotionDetectionService(emotion: .sad, confidence: 0.7)
        let result = await mock.analyze(pcmData: Data())
        let total = result.allScores.values.reduce(0, +)
        XCTAssertEqual(total, 1.0, accuracy: 0.0001, "Softmax-распределение суммируется в 1")
    }

    func testMockDominantEmotionHasHighestScore() async {
        let mock = MockEmotionDetectionService(emotion: .neutral, confidence: 0.6)
        let result = await mock.analyze(pcmData: Data())
        let dominant = result.allScores.max(by: { $0.value < $1.value })
        XCTAssertEqual(dominant?.key, .neutral)
    }

    func testMockAllFourEmotionsPresentInScores() async {
        let mock = MockEmotionDetectionService(emotion: .happy, confidence: 0.9)
        let result = await mock.analyze(pcmData: Data())
        XCTAssertEqual(Set(result.allScores.keys), Set(DetectedEmotion.allCases))
    }

    func testMockMutableEmotionProperty() async {
        let mock = MockEmotionDetectionService()
        mock.mockEmotion = .sad
        mock.mockConfidence = 0.55
        let result = await mock.analyze(pcmData: Data())
        XCTAssertEqual(result.emotion, .sad)
        XCTAssertEqual(result.confidence, 0.55, accuracy: 0.001)
    }

    // MARK: - LiveEmotionDetectionService (model-missing fallback)

    func testLiveReturnsNeutralWhenModelUnavailable() async {
        let service = LiveEmotionDetectionService()
        // Дать init-Task шанс отработать loadModel (модель отсутствует).
        try? await Task.sleep(nanoseconds: 50_000_000)
        let result = await service.analyze(pcmData: Data(repeating: 0, count: 1024))
        XCTAssertEqual(result.emotion, .neutral, "Без модели — детерминированный neutral fallback")
        XCTAssertEqual(result.confidence, 0.7, accuracy: 0.001)
    }

    func testLiveNeutralFallbackScoresSumToOne() async {
        let service = LiveEmotionDetectionService()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let result = await service.analyze(pcmData: Data())
        let total = result.allScores.values.reduce(0, +)
        XCTAssertEqual(total, 1.0, accuracy: 0.0001)
    }

    // MARK: - EmotionResult value type

    func testEmotionResultInit() {
        let result = EmotionResult(
            emotion: .happy,
            confidence: 0.88,
            allScores: [.happy: 0.88, .sad: 0.04, .frustrated: 0.04, .neutral: 0.04]
        )
        XCTAssertEqual(result.emotion, .happy)
        XCTAssertEqual(result.confidence, 0.88, accuracy: 0.001)
        XCTAssertEqual(result.allScores[.happy], 0.88)
    }
}
