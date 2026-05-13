import AVFoundation
import CoreML
import XCTest

@testable import HappySpeech

// MARK: - MLPerformanceTests

/// Бенчмарки ML-компонентов HappySpeech для Plan v13 Block P.
///
/// Performance targets (iPhone 17 Pro с ANE):
///   - RealMFCCExtractor.extract([Float]): < 10 ms per 1 sec audio
///   - RussianPhonemeClassifier predict: < 50 ms
///   - PronunciationScorer CoreML inference: < 100 ms
///   - Wav2Vec2RuChild (302 MB): NOT_MEASURABLE на симуляторе
///   - WhisperKit: NOT_MEASURABLE на симуляторе
///
/// Запуск:
///   xcodebuild test -project HappySpeech.xcodeproj -scheme HappySpeech \
///     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
///     -only-testing:HappySpeechTests/MLPerformanceTests
final class MLPerformanceTests: XCTestCase {

    // MARK: - Helpers

    /// Синтетический [Float] массив @ 16kHz длительностью 1 секунда.
    private func make1SecAudio(frequency: Float = 440, sampleRate: Int = 16_000) -> [Float] {
        (0 ..< sampleRate).map { i in
            sin(2.0 * .pi * frequency * Float(i) / Float(sampleRate)) * 0.5
        }
    }

    /// Синтетический MFCC массив [[Float]] — 39 коэффициентов × 150 фреймов.
    private func makeSyntheticMFCC(nCoeffs: Int = 39, nFrames: Int = 150) -> [[Float]] {
        (0 ..< nFrames).map { _ in
            (0 ..< nCoeffs).map { _ in Float.random(in: -3.0 ... 3.0) }
        }
    }

    // MARK: - RealMFCCExtractor

    /// Бенчмарк RealMFCCExtractor.extract([Float]) для 1 сек аудио @ 16kHz.
    ///
    /// Цель: < 10 ms на iPhone 17 Pro (ANE + vDSP).
    /// На симуляторе (CPU only) ожидаемо 15–40 ms.
    func testRealMFCCExtractor1SecPerformance() async {
        let audio = make1SecAudio()
        let extractor = RealMFCCExtractor()

        measure {
            let exp = expectation(description: "MFCC 1sec")
            Task {
                _ = await extractor.extract(from: audio)
                exp.fulfill()
            }
            wait(for: [exp], timeout: 5.0)
        }
    }

    /// Проверка формы вывода RealMFCCExtractor.
    /// Ожидается 39 коэффициентов на фрейм (13 base + 13 delta + 13 delta-delta).
    func testRealMFCCOutputCoefficientsCount() async {
        let audio = make1SecAudio()
        let extractor = RealMFCCExtractor()
        let frames = await extractor.extract(from: audio)

        XCTAssertFalse(frames.isEmpty, "RealMFCCExtractor не должен возвращать пустой массив")
        if let firstFrame = frames.first {
            XCTAssertEqual(firstFrame.count, 39,
                           "Каждый фрейм должен содержать 39 коэффициентов (13+13+13 с дельтами)")
        }
    }

    // MARK: - RussianPhonemeClassifier

    /// Бенчмарк RussianPhonemeClassifier.predict() с синтетическим MFCC.
    ///
    /// Цель: < 50 ms на iPhone 17 Pro.
    /// На симуляторе (CPU only, без ANE): ожидаемо 20–100 ms.
    ///
    /// Plan v22 Block 1.5: при отсутствии mlpackage в test bundle —
    /// используется `MockMLExecutor` для baseline regression testing
    /// (вместо XCTSkip NOT_MEASURABLE).
    func testRussianPhonemeClassifierPerformance() async throws {
        if Bundle.main.url(forResource: "RussianPhonemeClassifier", withExtension: "mlpackage") != nil {
            // Real model доступна — реальный inference
            let wrapper = try RussianPhonemeClassifierWrapper()
            let syntheticMFCC = makeSyntheticMFCC(
                nCoeffs: RussianPhonemeClassifierWrapper.nMFCC,
                nFrames: RussianPhonemeClassifierWrapper.nFrames
            )

            measure {
                let exp = expectation(description: "PhonemeClassifier")
                Task {
                    _ = try? await wrapper.predict(mfcc: syntheticMFCC)
                    exp.fulfill()
                }
                wait(for: [exp], timeout: 10.0)
            }
        } else {
            // Fallback на MockMLExecutor (baseline regression test)
            let executor = MockMLExecutor(classifyDelay: 0.04)
            let testData = Data(repeating: 0, count: 16_000 * 2)

            measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
                let exp = expectation(description: "PhonemeClassifierMock")
                Task {
                    _ = await executor.classify(audio: testData)
                    exp.fulfill()
                }
                wait(for: [exp], timeout: 5.0)
            }
        }
    }

    // MARK: - PronunciationScorer (CoreML direct)

    /// Прямой CoreML inference бенчмарк PronunciationScorer (без аудио I/O).
    ///
    /// Загружает первую доступную mlpackage и прогоняет inference с тензором [1,40,150].
    /// Цель: < 100 ms на iPhone 17 Pro.
    ///
    /// Plan v22 Block 1.5: при отсутствии mlpackage — fallback на MockMLExecutor
    /// для baseline regression testing.
    func testPronunciationScorerCoreMLPerformance() throws {
        let modelNames = [
            "PronunciationScorer_whistling",
            "PronunciationScorer_hissing",
            "PronunciationScorer_sonants",
            "PronunciationScorer_velar"
        ]

        if let modelName = modelNames.first(where: {
            Bundle.main.url(forResource: $0, withExtension: "mlpackage") != nil
        }),
        let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlpackage") {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            let model = try MLModel(contentsOf: modelURL, configuration: config)

            // Входной тензор [1, 40, 150]
            let shape: [NSNumber] = [1, 40, 150]
            guard let inputArray = try? MLMultiArray(shape: shape, dataType: .float32) else {
                XCTFail("Не удалось создать MLMultiArray [1,40,150]")
                return
            }
            for i in 0 ..< (1 * 40 * 150) {
                inputArray[i] = NSNumber(value: Float.random(in: -2.0 ... 2.0))
            }

            let provider = try MLDictionaryFeatureProvider(dictionary: ["mfcc": inputArray])

            measure {
                _ = try? model.prediction(from: provider)
            }
        } else {
            // Fallback на MockMLExecutor baseline (когда mlpackage отсутствует)
            let executor = MockMLExecutor(classifyDelay: 0.08)
            let testData = Data(repeating: 0, count: 16_000 * 2)

            measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
                let exp = expectation(description: "PronunciationScorerMock")
                Task {
                    _ = await executor.classify(audio: testData)
                    exp.fulfill()
                }
                wait(for: [exp], timeout: 5.0)
            }
        }
    }

    // MARK: - Wav2Vec2 (NOT_MEASURABLE)

    /// Wav2Vec2 batch inference baseline (MockMLExecutor surrogate).
    ///
    /// Plan v22 Block 1.5: реальный Wav2Vec2RuChild (302 MB) inference NOT_MEASURABLE
    /// на iOS Simulator (ANE недоступен, CPU 5–15x медленнее). Этот тест использует
    /// `MockMLExecutor` (200 ms latency target) как baseline regression test.
    ///
    /// Реальные замеры — на iPhone 15 Pro+ через Instruments + HSSignpost.
    func testWav2Vec2BatchInferenceBaseline() async throws {
        let executor = MockMLExecutor(classifyDelay: 0.2)
        let testData = Data(repeating: 0, count: 48_000 * 4) // 3 сек @ 16kHz float32

        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            let exp = expectation(description: "Wav2Vec2BatchMock")
            Task {
                for _ in 0..<3 {
                    _ = await executor.classify(audio: testData)
                }
                exp.fulfill()
            }
            wait(for: [exp], timeout: 10.0)
        }
    }

    // MARK: - WhisperKit (Mock baseline)

    /// WhisperKit warm inference baseline (MockMLExecutor surrogate).
    ///
    /// Plan v22 Block 1.5: реальный WhisperKit Tiny (~150 MB) грузится с HuggingFace
    /// runtime — NOT_MEASURABLE on Simulator. Этот тест baseline regression на
    /// `MockMLExecutor` (300 ms latency target, имитирует Whisper Tiny warm на A17).
    func testWhisperKitWarmInferenceBaseline() async throws {
        let executor = MockMLExecutor(classifyDelay: 0.3)
        let testData = Data(repeating: 0, count: 48_000 * 4) // 3 сек @ 16kHz float32

        // Warm-up call (не учитываем в metric)
        _ = await executor.classify(audio: testData)

        measure(metrics: [XCTClockMetric()]) {
            let exp = expectation(description: "WhisperKitWarmMock")
            Task {
                _ = await executor.classify(audio: testData)
                exp.fulfill()
            }
            wait(for: [exp], timeout: 5.0)
        }
    }

    // MARK: - ML Memory Footprint (Mock baseline)

    /// Memory footprint baseline через MockMLExecutor (20 sequential inferences).
    ///
    /// Plan v22 Block 1.5: реальные модели (Wav2Vec2 302 MB, Whisper 150 MB) дают
    /// нерепрезентативные числа на Simulator. Этот тест baseline на mock executor
    /// для regression на allocation patterns.
    func testMLMemoryFootprintBaseline() async throws {
        let executor = MockMLExecutor(classifyDelay: 0.02)
        let testData = Data(repeating: 0, count: 16_000 * 2)

        measure(metrics: [XCTMemoryMetric()]) {
            let exp = expectation(description: "MLMemoryFootprintMock")
            Task {
                for _ in 0..<20 {
                    _ = await executor.classify(audio: testData)
                }
                exp.fulfill()
            }
            wait(for: [exp], timeout: 10.0)
        }
    }
}
