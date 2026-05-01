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
    func testRussianPhonemeClassifierPerformance() async throws {
        guard Bundle.main.url(
            forResource: "RussianPhonemeClassifier",
            withExtension: "mlpackage"
        ) != nil else {
            throw XCTSkip("""
                NOT_MEASURABLE: RussianPhonemeClassifier.mlpackage недоступен в тестовом bundle.
                Добавь mlpackage в HappySpeechTests target → Build Phases → Copy Bundle Resources.
                Цель: < 50 ms на iPhone 17 Pro с ANE.
                """)
        }

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
    }

    // MARK: - PronunciationScorer (CoreML direct)

    /// Прямой CoreML inference бенчмарк PronunciationScorer (без аудио I/O).
    ///
    /// Загружает первую доступную mlpackage и прогоняет inference с тензором [1,40,150].
    /// Цель: < 100 ms на iPhone 17 Pro.
    func testPronunciationScorerCoreMLPerformance() throws {
        let modelNames = [
            "PronunciationScorer_whistling",
            "PronunciationScorer_hissing",
            "PronunciationScorer_sonants",
            "PronunciationScorer_velar"
        ]

        guard let modelName = modelNames.first(where: {
            Bundle.main.url(forResource: $0, withExtension: "mlpackage") != nil
        }),
        let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlpackage") else {
            throw XCTSkip("""
                NOT_MEASURABLE: Ни одна PronunciationScorer mlpackage недоступна в тестовом bundle.
                Цель: < 100 ms direct CoreML inference на iPhone 17 Pro.
                """)
        }

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
    }

    // MARK: - Wav2Vec2 (NOT_MEASURABLE)

    /// Wav2Vec2RuChild (302 MB) inference NOT_MEASURABLE на iOS Simulator.
    ///
    /// Причины:
    ///   1. Neural Engine недоступен на симуляторе — CPU inference ~5–15x медленнее цели
    ///   2. 302 MB модель — загрузка занимает >2 сек даже без inference
    ///   3. Репрезентативные данные получаемы только на A16 Bionic+ (iPhone 14 Pro+)
    ///
    /// Для замера: iPhone 15 Pro (A17 Pro с ANE), 1 сек аудио @ 16 kHz.
    /// Ожидаем: 200–450 ms (цель < 500 ms).
    func testWav2Vec2InferenceNotMeasurableOnSimulator() throws {
        throw XCTSkip("""
            NOT_MEASURABLE: Wav2Vec2RuChild (302 MB) inference не измеримо на iOS Simulator.
            ANE недоступен; CPU-only inference нерепрезентативен.
            Замер на iPhone 15 Pro+ с ANE. Цель: < 500 ms per 1 sec audio.
            """)
    }

    // MARK: - WhisperKit (NOT_MEASURABLE)

    /// WhisperKit warm inference NOT_MEASURABLE на iOS Simulator.
    func testWhisperKitWarmInferenceNotMeasurableOnSimulator() throws {
        throw XCTSkip("""
            NOT_MEASURABLE: WhisperKit inference не измеримо на iOS Simulator.
            Tiny модель (~150 MB) не bundled, загружается с HuggingFace.
            ANE недоступен на симуляторе.
            Цель: < 500 ms на 3 сек аудио на iPhone 15 Pro+.
            """)
    }
}
