@preconcurrency import AVFoundation
@preconcurrency import CoreML
import Accelerate
import OSLog

// MARK: - Domain Types

/// Группа звуков русского языка для логопедической работы.
enum PhonemeGroup: String, CaseIterable, Sendable {
    case whistling = "whistling"    // С, З, Ц
    case hissing = "hissing"        // Ш, Ж, Ч, Щ
    case sonants = "sonants"        // Р, Л
    case velar = "velar"            // К, Г, Х

    var localizedName: String {
        switch self {
        case .whistling: return String(localized: "Свистящие (С, З, Ц)")
        case .hissing:   return String(localized: "Шипящие (Ш, Ж, Ч, Щ)")
        case .sonants:   return String(localized: "Соноры (Р, Л)")
        case .velar:     return String(localized: "Заднеязычные (К, Г, Х)")
        }
    }

    var phonemes: [String] {
        switch self {
        case .whistling: return ["С", "З", "Ц"]
        case .hissing:   return ["Ш", "Ж", "Ч", "Щ"]
        case .sonants:   return ["Р", "Л"]
        case .velar:     return ["К", "Г", "Х"]
        }
    }
}

/// Результат оценки произношения.
struct PronunciationResult: Sendable {
    /// Вероятность правильного произношения (0.0–1.0).
    let correctProbability: Float
    /// Вероятность неправильного произношения (0.0–1.0).
    let incorrectProbability: Float
    /// Класс с максимальной вероятностью.
    let predictedLabel: String
    /// Группа звуков, для которой была оценка.
    let phonemeGroup: PhonemeGroup

    /// Удобный флаг: произношение считается правильным при correctProbability >= 0.6.
    var isCorrect: Bool { correctProbability >= 0.6 }

    /// Нормированный score для UI (0–100).
    var displayScore: Int { Int(correctProbability * 100) }
}

// MARK: - Protocol

/// Сервис оценки произношения. Все методы async для on-device ML inference.
protocol PronunciationScorerProtocol: Sendable {
    /// Оценивает произношение из буфера аудио.
    /// - Parameters:
    ///   - buffer: PCM-буфер 16kHz mono, 0.5–2.0 сек
    ///   - group: группа звуков для выбора нужной модели
    /// - Returns: результат оценки
    func score(
        audio buffer: AVAudioPCMBuffer,
        phonemeGroup group: PhonemeGroup
    ) async throws -> PronunciationResult
}

// MARK: - MFCC Feature Extraction

/// Извлечение MFCC через vDSP/Accelerate (native iOS, без Python зависимостей).
enum MFCCExtractor {
    static let nMFCC = 40
    static let hopLength = 160     // 10ms при 16kHz
    static let nFFT = 400          // 25ms при 16kHz
    static let targetSR: Double = 16000
    static let targetDuration: Double = 1.5
    static let targetSamples = Int(targetSR * targetDuration)  // 24000
    static let tSteps = (targetSamples + hopLength - 1) / hopLength  // 150

    /// Извлекает MFCC из PCM-буфера.
    /// - Returns: MLMultiArray shape [1, 40, 150] или nil при ошибке
    static func extract(from buffer: AVAudioPCMBuffer) throws -> MLMultiArray {
        guard let channelData = buffer.floatChannelData else {
            throw PronunciationScorerError.invalidAudioBuffer
        }

        let frameCount = Int(buffer.frameLength)
        var samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))

        // Ресемплинг до 16kHz если нужно
        if buffer.format.sampleRate != targetSR {
            samples = resample(
                samples,
                fromSR: buffer.format.sampleRate,
                toSR: targetSR
            )
        }

        // Pad/trim до targetSamples
        if samples.count < targetSamples {
            samples += [Float](repeating: 0, count: targetSamples - samples.count)
        } else {
            samples = Array(samples.prefix(targetSamples))
        }

        // Pre-emphasis filter
        var preEmphasized = [Float](repeating: 0, count: samples.count)
        preEmphasized[0] = samples[0]
        for i in 1..<samples.count {
            preEmphasized[i] = samples[i] - 0.97 * samples[i - 1]
        }

        // MFCC через DCT на mel filterbank
        let mfcc = computeMFCC(signal: preEmphasized)

        // Нормализация per-sample
        let normalized = normalize(mfcc)

        // Упаковка в MLMultiArray [1, nMFCC, tSteps]
        let multiArray = try MLMultiArray(
            shape: [1, NSNumber(value: nMFCC), NSNumber(value: tSteps)],
            dataType: .float32
        )

        for coeff in 0..<nMFCC {
            for t in 0..<tSteps {
                let idx = coeff * tSteps + t
                let arrayIdx = [0, coeff, t] as [NSNumber]
                multiArray[arrayIdx] = NSNumber(value: idx < normalized.count ? normalized[idx] : 0)
            }
        }

        return multiArray
    }

    // MARK: Private

    private static func resample(
        _ samples: [Float],
        fromSR: Double,
        toSR: Double
    ) -> [Float] {
        let ratio = toSR / fromSR
        let outputCount = Int(Double(samples.count) * ratio)
        var output = [Float](repeating: 0, count: outputCount)

        // Линейная интерполяция (простой ресемплинг)
        for i in 0..<outputCount {
            let pos = Double(i) / ratio
            let idx = Int(pos)
            let frac = Float(pos - Double(idx))
            if idx + 1 < samples.count {
                output[i] = samples[idx] * (1 - frac) + samples[idx + 1] * frac
            } else if idx < samples.count {
                output[i] = samples[idx]
            }
        }
        return output
    }

    private static func computeMFCC(signal: [Float]) -> [Float] {
        let numFrames = tSteps
        var mfcc = [Float](repeating: 0, count: nMFCC * numFrames)
        let nMelBands = 40

        // Mel filterbank параметры
        let melMin: Float = 0
        let melMax = hzToMel(Float(targetSR / 2))
        let melPoints = (0...nMelBands + 1).map { i in
            melMin + Float(i) * (melMax - melMin) / Float(nMelBands + 1)
        }
        let hzPoints = melPoints.map { melToHz($0) }
        let binPoints = hzPoints.map { Int($0 / Float(targetSR) * Float(nFFT)) }

        for frameIdx in 0..<numFrames {
            let start = frameIdx * hopLength
            let end = min(start + nFFT, signal.count)
            var frame = [Float](repeating: 0, count: nFFT)
            let copyLen = end - start
            if copyLen > 0 {
                frame.replaceSubrange(0..<copyLen, with: signal[start..<end])
            }

            // Hamming window
            var windowed = applyHamming(frame)

            // Power spectrum через vDSP FFT
            let powerSpectrum = computePowerSpectrum(&windowed)

            // Mel filterbank
            var melEnergies = [Float](repeating: 0, count: nMelBands)
            for m in 0..<nMelBands {
                let lo = binPoints[m]
                let center = binPoints[m + 1]
                let hi = binPoints[m + 2]

                var energy: Float = 0
                for k in lo..<center {
                    if k < powerSpectrum.count {
                        let weight = Float(k - lo) / Float(max(center - lo, 1))
                        energy += weight * powerSpectrum[k]
                    }
                }
                for k in center..<hi {
                    if k < powerSpectrum.count {
                        let weight = Float(hi - k) / Float(max(hi - center, 1))
                        energy += weight * powerSpectrum[k]
                    }
                }
                melEnergies[m] = log(max(energy, 1e-8))
            }

            // DCT для MFCC
            let nCoeffs = min(nMFCC, nMelBands)
            for n in 0..<nCoeffs {
                var sum: Float = 0
                for m in 0..<nMelBands {
                    sum += melEnergies[m] * cos(Float.pi * Float(n) * (Float(m) + 0.5) / Float(nMelBands))
                }
                mfcc[n * numFrames + frameIdx] = sum
            }
        }

        return mfcc
    }

    private static func hzToMel(_ hz: Float) -> Float {
        return 2595 * log10(1 + hz / 700)
    }

    private static func melToHz(_ mel: Float) -> Float {
        return 700 * (pow(10, mel / 2595) - 1)
    }

    private static func applyHamming(_ frame: [Float]) -> [Float] {
        let n = frame.count
        return frame.enumerated().map { i, sample in
            sample * (0.54 - 0.46 * cos(2 * Float.pi * Float(i) / Float(n - 1)))
        }
    }

    private static func computePowerSpectrum(_ frame: inout [Float]) -> [Float] {
        let n = frame.count
        let log2n = vDSP_Length(log2(Float(n)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return [Float](repeating: 0, count: n / 2 + 1)
        }
        defer { vDSP_destroy_fftsetup(setup) }

        var real = [Float](repeating: 0, count: n / 2)
        var imag = [Float](repeating: 0, count: n / 2)

        frame.withUnsafeBytes { rawPtr in
            guard let baseAddress = rawPtr.baseAddress else { return }
            var splitComplex = DSPSplitComplex(
                realp: &real,
                imagp: &imag
            )
            baseAddress.withMemoryRebound(to: DSPComplex.self, capacity: n / 2) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(n / 2))
            }
            vDSP_fft_zrip(setup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
        }

        var magnitudes = [Float](repeating: 0, count: n / 2)
        var splitComplex = DSPSplitComplex(realp: &real, imagp: &imag)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(n / 2))

        return magnitudes
    }

    private static func normalize(_ mfcc: [Float]) -> [Float] {
        var mean: Float = 0
        var stddev: Float = 0
        vDSP_meanv(mfcc, 1, &mean, vDSP_Length(mfcc.count))
        var variance: Float = 0
        var meanArr = [Float](repeating: mean, count: mfcc.count)
        var diff = [Float](repeating: 0, count: mfcc.count)
        vDSP_vsub(meanArr, 1, mfcc, 1, &diff, 1, vDSP_Length(mfcc.count))
        vDSP_measqv(diff, 1, &variance, vDSP_Length(mfcc.count))
        stddev = sqrt(variance) + 1e-8
        return mfcc.map { ($0 - mean) / stddev }
    }
}

// MARK: - Errors

enum PronunciationScorerError: LocalizedError, Sendable {
    case modelNotFound(PhonemeGroup)
    case invalidAudioBuffer
    case inferenceFailure(String)
    case featureExtractionFailure

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let group):
            return String(localized: "Модель для группы '\(group.localizedName)' не найдена")
        case .invalidAudioBuffer:
            return String(localized: "Некорректный аудио буфер")
        case .inferenceFailure(let detail):
            return String(localized: "Ошибка инференса модели: \(detail)")
        case .featureExtractionFailure:
            return String(localized: "Ошибка извлечения MFCC признаков")
        }
    }
}

// MARK: - Live Implementation

/// Реальная реализация PronunciationScorer через Core ML.
/// Загружает по одной модели на группу звуков лениво (при первом запросе).
actor LivePronunciationScorer: PronunciationScorerProtocol {
    private let logger = Logger(subsystem: "HappySpeech", category: "PronunciationScorer")
    private var loadedModels: [PhonemeGroup: MLModel] = [:]

    func score(
        audio buffer: AVAudioPCMBuffer,
        phonemeGroup group: PhonemeGroup
    ) async throws -> PronunciationResult {
        let model = try loadModel(for: group)
        let mfcc = try MFCCExtractor.extract(from: buffer)

        let input = try MLDictionaryFeatureProvider(dictionary: ["mfcc": mfcc])
        let output = try model.prediction(from: input)

        return try Self.parseOutput(output, group: group)
    }

    // MARK: Private

    private func loadModel(for group: PhonemeGroup) throws -> MLModel {
        if let existing = loadedModels[group] {
            return existing
        }

        let modelName = "PronunciationScorer_\(group.rawValue)"
        guard let modelURL = Bundle.main.url(
            forResource: modelName,
            withExtension: "mlpackage"
        ) else {
            logger.error("Model not found: \(modelName).mlpackage")
            throw PronunciationScorerError.modelNotFound(group)
        }

        let config = MLModelConfiguration()
        config.computeUnits = .all

        let model = try MLModel(contentsOf: modelURL, configuration: config)
        loadedModels[group] = model
        logger.info("Loaded model: \(modelName)")
        return model
    }

    nonisolated private static func parseOutput(
        _ output: MLFeatureProvider,
        group: PhonemeGroup
    ) throws -> PronunciationResult {
        // Ожидаем выход "output" — float32 [1, 2] (logits)
        guard let outputFeature = output.featureValue(for: "output"),
              let multiArray = outputFeature.multiArrayValue else {
            throw PronunciationScorerError.inferenceFailure("Missing output feature")
        }

        // Softmax вручную
        let logit0 = multiArray[[0, 0] as [NSNumber]].floatValue
        let logit1 = multiArray[[0, 1] as [NSNumber]].floatValue
        let maxLogit = max(logit0, logit1)
        let exp0 = exp(logit0 - maxLogit)
        let exp1 = exp(logit1 - maxLogit)
        let sumExp = exp0 + exp1

        let correctProb = exp0 / sumExp
        let incorrectProb = exp1 / sumExp

        return PronunciationResult(
            correctProbability: correctProb,
            incorrectProbability: incorrectProb,
            predictedLabel: correctProb >= 0.5 ? "correct" : "incorrect",
            phonemeGroup: group
        )
    }
}

// MARK: - Mock Implementation

/// Мок-реализация для unit-тестов и Preview.
final class MockPronunciationScorer: PronunciationScorerProtocol, @unchecked Sendable {
    /// Если true — всегда возвращает "correct". Если false — "incorrect".
    var alwaysCorrect: Bool = true
    /// Фиксированная вероятность для тестирования.
    var fixedProbability: Float = 0.85
    /// Задержка инференса для симуляции (секунды).
    var simulatedLatency: TimeInterval = 0

    func score(
        audio buffer: AVAudioPCMBuffer,
        phonemeGroup group: PhonemeGroup
    ) async throws -> PronunciationResult {
        if simulatedLatency > 0 {
            try await Task.sleep(for: .seconds(simulatedLatency))
        }

        let correctProb = alwaysCorrect ? fixedProbability : (1 - fixedProbability)
        let incorrectProb = 1 - correctProb

        return PronunciationResult(
            correctProbability: correctProb,
            incorrectProbability: incorrectProb,
            predictedLabel: alwaysCorrect ? "correct" : "incorrect",
            phonemeGroup: group
        )
    }
}
