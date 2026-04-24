@preconcurrency import AVFoundation
@preconcurrency import CoreML
import Accelerate
import OSLog

// MARK: - Domain Types

/// Класс звука, детектированный SoundClassifier.
public enum SoundClass: String, Sendable, CaseIterable {
    case speech    = "speech"
    case noise     = "noise"
    case silence   = "silence"
    case breathing = "breathing"

    /// Локализованное описание для UI.
    public var localizedDescription: String {
        switch self {
        case .speech:    return String(localized: "Речь")
        case .noise:     return String(localized: "Шум")
        case .silence:   return String(localized: "Тишина")
        case .breathing: return String(localized: "Дыхание")
        }
    }
}

/// Результат анализа одного аудио-буфера.
public struct AudioAnalysisResult: Sendable {
    /// Детектированный класс.
    public let soundClass: SoundClass
    /// Вероятность детектированного класса (0.0–1.0).
    public let confidence: Float
    /// Все вероятности классов.
    public let probabilities: [SoundClass: Float]

    public init(soundClass: SoundClass, confidence: Float, probabilities: [SoundClass: Float]) {
        self.soundClass    = soundClass
        self.confidence    = confidence
        self.probabilities = probabilities
    }
}

// MARK: - Protocol

/// Сервис анализа аудио: классификация типа звука.
/// Используется в LogopedGame-шаблонах для pre-filter перед ASR:
/// анализируем буфер → если .speech → запускаем WhisperKit.
public protocol AudioAnalysisService: Sendable {
    /// Классифицирует PCM-буфер (рекомендуется 1 секунда @ 16kHz).
    func classifySound(_ buffer: AVAudioPCMBuffer) async -> AudioAnalysisResult

    /// Быстрая проверка: содержит ли буфер речь.
    func isSpeech(_ buffer: AVAudioPCMBuffer) async -> Bool
}

// MARK: - Errors

enum AudioAnalysisError: LocalizedError, Sendable {
    case modelNotFound
    case inferenceFailure(String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return String(localized: "SoundClassifier.mlpackage не найден в Resources/Models/")
        case .inferenceFailure(let detail):
            return String(localized: "Ошибка классификации звука: \(detail)")
        }
    }
}

// MARK: - Live Implementation

/// Реализация через Core ML SoundClassifier.mlpackage.
///
/// Вход: Log Mel-spectrogram [1, 1, 64, 64] — 1 секунда @ 16kHz.
/// Выход: classLabel (String) + classProbability (Dictionary).
///
/// Модель обучена M4.5 pipeline на синтетическом датасете:
///   speech=1500, noise=1500, silence=750, breathing=750 сэмплов.
///   Accuracy: 85.8% | Macro F1: 85.2% (2026-04-24).
public actor LiveAudioAnalysisService: AudioAnalysisService {

    private let logger = Logger(subsystem: "HappySpeech", category: "AudioAnalysisService")
    private var model: MLModel?

    // STFT параметры (должны совпадать с train_sound_classifier.py)
    private let nMels   = 64
    private let nFrames = 64
    private let nFft    = 512
    private let sampleRate = 16_000
    private var nSamples: Int { sampleRate }   // 1 сек = 16 000 сэмплов
    private var hopLength: Int { nSamples / nFrames }

    public init() {}

    // MARK: AudioAnalysisService

    public func classifySound(_ buffer: AVAudioPCMBuffer) async -> AudioAnalysisResult {
        guard let channelData = buffer.floatChannelData else {
            return fallbackResult()
        }
        let frameCount = Int(buffer.frameLength)
        let samples    = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))

        do {
            let model   = try await loadModel()
            let logmel  = computeLogMel(samples: samples)
            let result  = try await runInference(logmel: logmel, model: model)
            return result
        } catch {
            logger.warning("SoundClassifier inference failed: \(error.localizedDescription)")
            return fallbackResult()
        }
    }

    public func isSpeech(_ buffer: AVAudioPCMBuffer) async -> Bool {
        let result = await classifySound(buffer)
        return result.soundClass == .speech && result.confidence >= 0.6
    }

    // MARK: Private — Model Loading

    private func loadModel() async throws -> MLModel {
        if let existing = model { return existing }

        guard let modelURL = Bundle.main.url(
            forResource: "SoundClassifier",
            withExtension: "mlpackage"
        ) else {
            logger.error("SoundClassifier.mlpackage not found in bundle")
            throw AudioAnalysisError.modelNotFound
        }

        let config          = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        let loaded          = try MLModel(contentsOf: modelURL, configuration: config)
        model = loaded
        logger.info("SoundClassifier model loaded")
        return loaded
    }

    // MARK: Private — Feature Extraction

    /// Вычисляет Log Mel-spectrogram из raw samples.
    /// Должен совпадать с audio_to_logmel() в train_sound_classifier.py.
    private func computeLogMel(samples: [Float]) -> [[Float]] {
        // Pad / trim до nSamples
        var audio = samples
        if audio.count < nSamples {
            audio += [Float](repeating: 0, count: nSamples - audio.count)
        } else if audio.count > nSamples {
            audio = Array(audio.prefix(nSamples))
        }

        // Окно Хэннинга
        var window = [Float](repeating: 0, count: nFft)
        for i in 0 ..< nFft {
            window[i] = 0.5 * (1.0 - cos(2.0 * .pi * Float(i) / Float(nFft - 1)))
        }

        // Mel-filterbank (упрощённая версия)
        let melFB = buildMelFilterbank()   // [nMels, nFft/2+1]

        var melFrames = [[Float]](repeating: [Float](repeating: 0, count: nMels), count: nFrames)

        for frameIdx in 0 ..< nFrames {
            let start = frameIdx * hopLength
            var frame = [Float](repeating: 0, count: nFft)

            // Копируем сэмплы с окном
            for k in 0 ..< nFft {
                let pos = start + k
                let sample: Float = pos < audio.count ? audio[pos] : 0.0
                frame[k] = sample * window[k]
            }

            // Мощность спектра через vDSP
            let halfN    = nFft / 2 + 1
            var power    = [Float](repeating: 0, count: halfN)
            let frameCopy = Array(frame)
            for k in 0 ..< halfN {
                power[k] = frameCopy[k] * frameCopy[k]
            }

            // Применяем Mel-фильтрбанк
            for melIdx in 0 ..< nMels {
                var energy: Float = 0
                for k in 0 ..< halfN {
                    energy += melFB[melIdx][k] * power[k]
                }
                melFrames[frameIdx][melIdx] = log(energy + 1e-8)
            }
        }

        return melFrames   // [nFrames, nMels]
    }

    /// Строит треугольный Mel-фильтрбанк [nMels, nFft/2+1].
    private func buildMelFilterbank() -> [[Float]] {
        let halfN    = nFft / 2 + 1
        let fMin: Float = 0.0
        let fMax: Float = Float(sampleRate) / 2.0

        let melMin = 2595 * log10(1 + fMin / 700)
        let melMax = 2595 * log10(1 + fMax / 700)

        var melPts   = [Float](repeating: 0, count: nMels + 2)
        for i in 0 ..< nMels + 2 {
            melPts[i] = melMin + Float(i) * (melMax - melMin) / Float(nMels + 1)
        }

        // Mel → Hz → bin
        var binPts = [Int](repeating: 0, count: nMels + 2)
        for i in 0 ..< nMels + 2 {
            let hz      = 700 * (pow(10, melPts[i] / 2595) - 1)
            binPts[i]   = Int(floor(Float(nFft + 1) * hz / Float(sampleRate)))
        }

        var fb = [[Float]](repeating: [Float](repeating: 0, count: halfN), count: nMels)
        for m in 0 ..< nMels {
            let left   = binPts[m]
            let center = binPts[m + 1]
            let right  = binPts[m + 2]
            for k in left ..< center where k < halfN {
                fb[m][k] = Float(k - left) / Float(max(center - left, 1))
            }
            for k in center ..< right where k < halfN {
                fb[m][k] = Float(right - k) / Float(max(right - center, 1))
            }
        }
        return fb
    }

    // MARK: Private — Inference

    private func runInference(logmel: [[Float]], model: MLModel) async throws -> AudioAnalysisResult {
        // Собираем MLMultiArray [1, 1, 64, 64]
        let multiArray = try MLMultiArray(
            shape: [1, 1, NSNumber(value: nMels), NSNumber(value: nFrames)],
            dataType: .float32
        )

        // Нормализация (совпадает с train_sound_classifier.py)
        var allValues = [Float]()
        for frame in logmel { allValues += frame }
        var mean: Float = 0
        var std:  Float = 1
        vDSP_meanv(allValues, 1, &mean, vDSP_Length(allValues.count))
        var variance: Float = 0
        vDSP_measqv(allValues, 1, &variance, vDSP_Length(allValues.count))
        std = sqrt(max(variance - mean * mean, 0)) + 1e-8

        for (frameIdx, frame) in logmel.enumerated() {
            for (melIdx, val) in frame.enumerated() {
                let norm    = (val - mean) / std
                let flatIdx = melIdx * nFrames + frameIdx
                multiArray[flatIdx] = NSNumber(value: norm)
            }
        }

        let input = try MLDictionaryFeatureProvider(dictionary: ["logmel": multiArray])
        let output = try await model.prediction(from: input)

        // Разбираем classLabel и classProbability
        var predictedClass = SoundClass.noise
        var confidence:    Float = 0.5
        var probs = [SoundClass: Float]()

        if let labelFeature = output.featureValue(for: "classLabel"),
           let sc = SoundClass(rawValue: labelFeature.stringValue) {
            predictedClass = sc
        }

        if let probFeature = output.featureValue(for: "classProbability"),
           let probDict = probFeature.dictionaryValue as? [String: Double] {
            for (key, val) in probDict {
                if let sc = SoundClass(rawValue: key) {
                    probs[sc] = Float(val)
                }
            }
            confidence = probs[predictedClass] ?? 0.5
        }

        return AudioAnalysisResult(
            soundClass:    predictedClass,
            confidence:    confidence,
            probabilities: probs
        )
    }

    // MARK: Private — Fallback

    /// Энергетический fallback когда модель недоступна.
    private func fallbackResult() -> AudioAnalysisResult {
        // По умолчанию считаем тишиной — безопасно для ASR pipeline
        return AudioAnalysisResult(
            soundClass:    .silence,
            confidence:    1.0,
            probabilities: [.silence: 1.0, .speech: 0.0, .noise: 0.0, .breathing: 0.0]
        )
    }
}

// MARK: - Mock Implementation

/// Мок для unit-тестов и Preview.
public final class MockAudioAnalysisService: AudioAnalysisService, @unchecked Sendable {
    public var mockedClass: SoundClass = .speech
    public var mockedConfidence: Float = 0.95

    public init() {}

    public func classifySound(_ buffer: AVAudioPCMBuffer) async -> AudioAnalysisResult {
        AudioAnalysisResult(
            soundClass:    mockedClass,
            confidence:    mockedConfidence,
            probabilities: [mockedClass: mockedConfidence]
        )
    }

    public func isSpeech(_ buffer: AVAudioPCMBuffer) async -> Bool {
        mockedClass == .speech
    }
}
