@preconcurrency import AVFoundation
@preconcurrency import CoreML
import Accelerate
import OSLog

// MARK: - Domain Types

/// Результат детекции голосовой активности.
struct VADResult: Sendable {
    /// Вероятность наличия речи в данном чанке (0.0–1.0).
    let speechProbability: Float
    /// Интерпретация: речь обнаружена при probability >= threshold.
    let isSpeech: Bool
    /// Порог, использованный при классификации.
    let threshold: Float
    /// Временная метка чанка (секунды от начала записи).
    let timestamp: TimeInterval

    /// Константы для работы с Silero VAD.
    enum Constants {
        /// Размер чанка: 512 сэмплов при 16kHz = 32ms.
        static let chunkSize = 512
        /// Целевая частота дискретизации.
        static let sampleRate: Int = 16000
        /// Порог по умолчанию (0.5 = оригинальный Silero VAD).
        static let defaultThreshold: Float = 0.5
    }
}

/// Агрегированный результат VAD для всей записи.
struct VADSession: Sendable {
    let chunks: [VADResult]

    /// Речь обнаружена если хотя бы N% чанков содержат речь.
    var hasSpeech: Bool {
        let speechChunks = chunks.filter { $0.isSpeech }.count
        return Double(speechChunks) / Double(max(chunks.count, 1)) >= 0.3
    }

    /// Оценочная продолжительность речи в секундах.
    var speechDuration: TimeInterval {
        let speechChunks = chunks.filter { $0.isSpeech }.count
        return TimeInterval(speechChunks) * TimeInterval(VADResult.Constants.chunkSize) /
               TimeInterval(VADResult.Constants.sampleRate)
    }

    /// Первый момент начала речи (секунды).
    var speechStart: TimeInterval? {
        chunks.first(where: { $0.isSpeech })?.timestamp
    }

    /// Последний момент речи (секунды).
    var speechEnd: TimeInterval? {
        chunks.last(where: { $0.isSpeech })?.timestamp
    }
}

// MARK: - Protocol

/// Сервис детекции голосовой активности.
protocol VADProtocol: Sendable {
    /// Обрабатывает один 512-сэмпловый чанк.
    func detectSpeech(
        chunk: AVAudioPCMBuffer,
        timestamp: TimeInterval
    ) async throws -> VADResult

    /// Обрабатывает целый буфер (разбивает на чанки автоматически).
    func processBuffer(
        _ buffer: AVAudioPCMBuffer
    ) async throws -> VADSession
}

// MARK: - Errors

enum VADError: LocalizedError, Sendable {
    case modelNotFound
    case invalidChunkSize(Int)
    case invalidSampleRate(Double)
    case inferenceFailure(String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return String(localized: "Модель Silero VAD не найдена в Resources/Models/")
        case .invalidChunkSize(let size):
            return String(localized: "Неверный размер чанка: \(size), ожидается 512")
        case .invalidSampleRate(let sr):
            return String(localized: "Неверная частота дискретизации: \(sr)Hz, ожидается 16000Hz")
        case .inferenceFailure(let detail):
            return String(localized: "Ошибка инференса VAD: \(detail)")
        }
    }
}

// MARK: - Live Implementation

/// Реальная реализация через Core ML Silero VAD.
actor LiveSileroVAD: VADProtocol {
    private let logger = Logger(subsystem: "HappySpeech", category: "SileroVAD")
    private var model: MLModel?
    private let threshold: Float
    private let chunkSize = VADResult.Constants.chunkSize
    private let targetSR = VADResult.Constants.sampleRate

    init(threshold: Float = VADResult.Constants.defaultThreshold) {
        self.threshold = threshold
    }

    func detectSpeech(
        chunk: AVAudioPCMBuffer,
        timestamp: TimeInterval
    ) async throws -> VADResult {
        // Extract samples on the caller side — buffer is transferred to the actor.
        guard let channelData = chunk.floatChannelData else {
            throw VADError.inferenceFailure("No channel data")
        }
        let frameCount = Int(chunk.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
        let model = try await loadModel()
        let prob = try await runChunkInference(samples: samples, model: model)
        return VADResult(
            speechProbability: prob,
            isSpeech: prob >= threshold,
            threshold: threshold,
            timestamp: timestamp
        )
    }

    func processBuffer(
        _ buffer: AVAudioPCMBuffer
    ) async throws -> VADSession {
        guard buffer.format.sampleRate == Double(targetSR) else {
            throw VADError.invalidSampleRate(buffer.format.sampleRate)
        }

        let totalFrames = Int(buffer.frameLength)
        var results: [VADResult] = []

        guard let channelData = buffer.floatChannelData else {
            throw VADError.inferenceFailure("No channel data")
        }

        let model = try await loadModel()
        var chunkStart = 0
        while chunkStart + chunkSize <= totalFrames {
            let chunkSamples = Array(
                UnsafeBufferPointer(
                    start: channelData[0].advanced(by: chunkStart),
                    count: chunkSize
                )
            )

            let timestamp = TimeInterval(chunkStart) / TimeInterval(targetSR)
            let prob = try await runChunkInference(samples: chunkSamples, model: model)

            results.append(VADResult(
                speechProbability: prob,
                isSpeech: prob >= threshold,
                threshold: threshold,
                timestamp: timestamp
            ))

            chunkStart += chunkSize
        }

        return VADSession(chunks: results)
    }

    // MARK: Private

    private func loadModel() async throws -> MLModel {
        if let existing = model {
            return existing
        }

        guard let modelURL = Bundle.main.url(
            forResource: "SileroVAD",
            withExtension: "mlpackage"
        ) else {
            logger.error("SileroVAD.mlpackage not found in bundle")
            throw VADError.modelNotFound
        }

        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine  // VAD: не нужен GPU

        let loaded = try MLModel(contentsOf: modelURL, configuration: config)
        model = loaded
        logger.info("SileroVAD model loaded")
        return loaded
    }

    private func runInference(
        chunk: AVAudioPCMBuffer,
        model: MLModel
    ) async throws -> Float {
        guard let channelData = chunk.floatChannelData else {
            throw VADError.inferenceFailure("No channel data")
        }
        let frameCount = Int(chunk.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
        return try await runChunkInference(samples: samples, model: model)
    }

    private func runChunkInference(samples: [Float], model: MLModel) async throws -> Float {
        // Упаковываем в MLMultiArray [1, 512]
        let multiArray = try MLMultiArray(
            shape: [1, NSNumber(value: chunkSize)],
            dataType: .float32
        )

        let padded = samples.count < chunkSize
            ? samples + [Float](repeating: 0, count: chunkSize - samples.count)
            : Array(samples.prefix(chunkSize))

        for (i, value) in padded.enumerated() {
            multiArray[[0, i] as [NSNumber]] = NSNumber(value: value)
        }

        let input = try MLDictionaryFeatureProvider(
            dictionary: ["audio_chunk": multiArray]
        )
        let output = try await model.prediction(from: input)

        // Ожидаем выход "speech_prob" — float32 [1, 1]
        if let probFeature = output.featureValue(for: "speech_prob"),
           let probArray = probFeature.multiArrayValue {
            return probArray[0].floatValue
        }

        // Fallback: пробуем первый доступный выход
        let featureNames = output.featureNames
        for name in featureNames {
            if let val = output.featureValue(for: name)?.multiArrayValue {
                return val[0].floatValue
            }
        }

        throw VADError.inferenceFailure("Cannot parse model output")
    }
}

// MARK: - Amplitude Fallback

/// Амплитудный детектор — fallback если CoreML модель недоступна.
/// Точность ~70–80% vs Silero ~95%, но работает без модели.
actor AmplitudeVAD: VADProtocol {
    private let energyThreshold: Float
    private let chunkSize = VADResult.Constants.chunkSize

    init(energyThreshold: Float = 0.01) {
        self.energyThreshold = energyThreshold
    }

    nonisolated func detectSpeech(
        chunk: AVAudioPCMBuffer,
        timestamp: TimeInterval
    ) async throws -> VADResult {
        guard let channelData = chunk.floatChannelData else {
            throw VADError.inferenceFailure("No channel data")
        }
        let frameCount = Int(chunk.frameLength)

        var rms: Float = 0
        vDSP_measqv(channelData[0], 1, &rms, vDSP_Length(frameCount))
        rms = sqrt(rms)

        // Нелинейное отображение в вероятность [0, 1]
        let prob = Self.sigmoid((rms - energyThreshold) * 50)

        return VADResult(
            speechProbability: prob,
            isSpeech: rms >= energyThreshold,
            threshold: energyThreshold,
            timestamp: timestamp
        )
    }

    nonisolated func processBuffer(
        _ buffer: AVAudioPCMBuffer
    ) async throws -> VADSession {
        let totalFrames = Int(buffer.frameLength)
        guard let channelData = buffer.floatChannelData else {
            return VADSession(chunks: [])
        }

        var results: [VADResult] = []
        var chunkStart = 0

        while chunkStart + chunkSize <= totalFrames {
            var rms: Float = 0
            vDSP_measqv(channelData[0].advanced(by: chunkStart), 1, &rms, vDSP_Length(chunkSize))
            rms = sqrt(rms)

            let timestamp = TimeInterval(chunkStart) / TimeInterval(VADResult.Constants.sampleRate)
            let prob = Self.sigmoid((rms - energyThreshold) * 50)

            results.append(VADResult(
                speechProbability: prob,
                isSpeech: rms >= energyThreshold,
                threshold: energyThreshold,
                timestamp: timestamp
            ))

            chunkStart += chunkSize
        }

        return VADSession(chunks: results)
    }

    nonisolated private static func sigmoid(_ x: Float) -> Float {
        return 1 / (1 + exp(-x))
    }
}

// MARK: - Mock Implementation

/// Мок для unit-тестов и Preview.
final class MockSileroVAD: VADProtocol, @unchecked Sendable {
    var speechProbability: Float = 0.9
    var simulatedLatency: TimeInterval = 0

    func detectSpeech(
        chunk: AVAudioPCMBuffer,
        timestamp: TimeInterval
    ) async throws -> VADResult {
        if simulatedLatency > 0 {
            try await Task.sleep(for: .seconds(simulatedLatency))
        }
        return VADResult(
            speechProbability: speechProbability,
            isSpeech: speechProbability >= VADResult.Constants.defaultThreshold,
            threshold: VADResult.Constants.defaultThreshold,
            timestamp: timestamp
        )
    }

    func processBuffer(_ buffer: AVAudioPCMBuffer) async throws -> VADSession {
        let chunks = stride(from: 0, to: Int(buffer.frameLength), by: VADResult.Constants.chunkSize).map { offset in
            VADResult(
                speechProbability: speechProbability,
                isSpeech: speechProbability >= VADResult.Constants.defaultThreshold,
                threshold: VADResult.Constants.defaultThreshold,
                timestamp: TimeInterval(offset) / TimeInterval(VADResult.Constants.sampleRate)
            )
        }
        return VADSession(chunks: chunks)
    }
}
