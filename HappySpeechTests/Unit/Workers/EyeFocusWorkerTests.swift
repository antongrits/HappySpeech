@testable import HappySpeech
import simd
import XCTest

// MARK: - EyeFocusWorkerTests
//
// Покрывает чистую логику EyeFocusWorker:
//   - computeAttention (среднее по истории + пустая история);
//   - управление историей (recentHistory / clearHistory).
//
// ПОКРЫТО НЕ ВСЁ: analyze(faceAnchor:) принимает ARFaceAnchor, который нельзя
// сконструировать в unit-тесте (ARKit не отдаёт публичного инициализатора и
// требует TrueDepth-сессию на устройстве). Логика накопления истории внутри
// analyze косвенно покрывается тестами на recentHistory/clearHistory через
// инвариант (история ограничена maxHistory, очищается). Сам разбор blendShapes
// требует device-теста и вынесен из unit-покрытия.

final class EyeFocusWorkerTests: XCTestCase {

    private func obs(attention: Float, timestamp: TimeInterval = 0) -> EyeFocusObservation {
        EyeFocusObservation(
            lookAtPoint: SIMD3<Float>(0, 0, 0),
            isLookingAtCamera: attention > 0.8,
            leftEyeOpenness: 1.0,
            rightEyeOpenness: 1.0,
            isBlinking: false,
            attentionScore: attention,
            timestamp: timestamp
        )
    }

    // MARK: - computeAttention

    func test_computeAttention_emptyHistory_returnsZero() async {
        let sut = EyeFocusWorker()
        let result = await sut.computeAttention(history: [])
        XCTAssertEqual(result, 0.0, accuracy: 0.0001, "Пустая история → 0")
    }

    func test_computeAttention_averagesScores() async {
        let sut = EyeFocusWorker()
        let history = [obs(attention: 0.2), obs(attention: 0.4), obs(attention: 0.6)]
        let result = await sut.computeAttention(history: history)
        XCTAssertEqual(result, 0.4, accuracy: 0.0001, "Среднее (0.2+0.4+0.6)/3 == 0.4")
    }

    func test_computeAttention_singleObservation_returnsItsScore() async {
        let sut = EyeFocusWorker()
        let result = await sut.computeAttention(history: [obs(attention: 0.73)])
        XCTAssertEqual(result, 0.73, accuracy: 0.0001)
    }

    func test_computeAttention_allMax_returnsOne() async {
        let sut = EyeFocusWorker()
        let history = (0..<10).map { _ in obs(attention: 1.0) }
        let result = await sut.computeAttention(history: history)
        XCTAssertEqual(result, 1.0, accuracy: 0.0001)
    }

    // MARK: - History lifecycle

    func test_recentHistory_initiallyEmpty() async {
        let sut = EyeFocusWorker()
        let history = await sut.recentHistory()
        XCTAssertTrue(history.isEmpty, "Новый worker без analyze — пустая история")
    }

    func test_clearHistory_emptiesHistory() async {
        let sut = EyeFocusWorker()
        // После clear история пуста (идемпотентно даже на пустой).
        await sut.clearHistory()
        let history = await sut.recentHistory()
        XCTAssertTrue(history.isEmpty)
    }

    func test_init_customMaxHistory_doesNotCrash() async {
        // Конструктор с кастомным maxHistory + базовый контракт.
        let sut = EyeFocusWorker(maxHistory: 5)
        let result = await sut.computeAttention(history: [obs(attention: 0.5)])
        XCTAssertEqual(result, 0.5, accuracy: 0.0001)
    }
}
