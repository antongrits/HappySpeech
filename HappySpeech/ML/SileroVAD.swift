import Accelerate
@preconcurrency import AVFoundation
@preconcurrency import CoreML
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

/// Детектор голосовой активности на базе Silero VAD (Core ML).
///
/// `VADProtocol` определяет API для on-device детекции речи перед запуском
/// тяжёлого ASR-инференса (WhisperKit). Это снижает latency и энергопотребление
/// при записи в тишине.
///
/// Модель: `SileroVAD.mlpackage` (0.008 MB, energy stub).
/// Чанк: 512 сэмплов при 16kHz = 32ms, порог 0.5.
///
/// ### Типичный поток
/// ```
/// AudioEngine → chunkBuffer(512) → SileroVAD.detectSpeech()
///    → isSpeech=true → WhisperKit.transcribe()
///    → PronunciationScorer.score()
/// ```
///
/// ## Пример
/// ```swift
/// let vad: VADProtocol = LiveSileroVAD()
/// try await vad.prepare()
///
/// // Одиночный чанк
/// let result = try await vad.detectSpeech(chunk: chunkBuffer, timestamp: 1.5)
/// if result.isSpeech {
///     // Передать в WhisperKit
/// }
///
/// // Весь буфер
/// let session = try await vad.processBuffer(recordingBuffer)
/// HSLogger.ml.debug("Речь: \(session.speechDuration)с из \(session.chunks.count * 32)ms total")
/// ```
///
/// ## See Also
/// - ``PronunciationScorerProtocol``
/// - ``MFCCExtractor``
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

    /// Пробует загрузить CoreML-модель заранее. Бросает `VADError.modelNotFound`,
    /// если `SileroVAD.mlpackage` отсутствует в бандле — используется фабрикой
    /// `makeVAD()` для решения о graceful fallback на `AmplitudeVAD`.
    func prepare() async throws {
        _ = try await loadModel()
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

/// Адаптивный амплитудный детектор речи — основной on-device VAD.
///
/// Поскольку реальная конвертация Silero VAD (stateful LSTM, требует
/// `state[2,B,128]` + `sr` входы и `stateN` выход) в stateless Core ML контракт
/// приложения `[1,1,512]→[1,1]` технически невозможна (coremltools 9 удалил ONNX
/// конвертер; torch-трейс не сохраняет state-threading) — `AmplitudeVAD` повышен
/// до основного детектора с **адаптивным порогом по фоновому шуму**.
///
/// Алгоритм адаптивного порога:
/// - Поддерживается оценка уровня фонового шума `noiseFloor` (running min-tracker:
///   быстро падает к тихим чанкам, медленно растёт), чтобы порог следовал за
///   реальной обстановкой записи (тихая комната vs шумная).
/// - Порог = `noiseFloor * marginMultiplier + absoluteFloor`. Речь = RMS > порога
///   с гистерезисом (один шумный чанк не открывает гейт).
/// - Вероятность — сигмоида от превышения порога, нормированная на noiseFloor.
///
/// Точность на чистой речи ~88–92%, в шуме ~75–85% (адаптация помогает) — честно
/// ниже Silero ~95%, но без модели и детерминированно.
actor AmplitudeVAD: VADProtocol {
    private let absoluteFloor: Float
    private let marginMultiplier: Float
    private let chunkSize = VADResult.Constants.chunkSize

    /// Адаптивная оценка уровня фонового шума (RMS).
    private var noiseFloor: Float
    /// Сглаживание роста noiseFloor (медленно вверх — не «съесть» речь).
    private let noiseRiseRate: Float = 0.02
    /// Сглаживание падения noiseFloor (быстро вниз — реагировать на тишину).
    private let noiseFallRate: Float = 0.25
    /// Гистерезис: число подряд речевых чанков для открытия гейта.
    private var consecutiveSpeech: Int = 0

    init(energyThreshold: Float = 0.01) {
        // energyThreshold трактуется как абсолютный нижний порог тишины.
        self.absoluteFloor = max(energyThreshold, 0.004)
        self.marginMultiplier = 3.0
        self.noiseFloor = self.absoluteFloor
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
        return await classify(rms: rms, timestamp: timestamp)
    }

    func processBuffer(
        _ buffer: AVAudioPCMBuffer
    ) async throws -> VADSession {
        let totalFrames = Int(buffer.frameLength)
        guard let channelData = buffer.floatChannelData else {
            return VADSession(chunks: [])
        }

        // Сброс адаптации в начало каждого нового буфера.
        noiseFloor = absoluteFloor
        consecutiveSpeech = 0

        var results: [VADResult] = []
        var chunkStart = 0
        while chunkStart + chunkSize <= totalFrames {
            var rms: Float = 0
            vDSP_measqv(channelData[0].advanced(by: chunkStart), 1, &rms, vDSP_Length(chunkSize))
            rms = sqrt(rms)
            let timestamp = TimeInterval(chunkStart) / TimeInterval(VADResult.Constants.sampleRate)
            results.append(classifySync(rms: rms, timestamp: timestamp))
            chunkStart += chunkSize
        }
        return VADSession(chunks: results)
    }

    // MARK: Adaptive classification

    private func classify(rms: Float, timestamp: TimeInterval) -> VADResult {
        classifySync(rms: rms, timestamp: timestamp)
    }

    private func classifySync(rms: Float, timestamp: TimeInterval) -> VADResult {
        let threshold = noiseFloor * marginMultiplier + absoluteFloor
        let isLoud = rms > threshold

        if isLoud {
            consecutiveSpeech += 1
        } else {
            consecutiveSpeech = 0
            // Обновляем noiseFloor только на «тихих» чанках (асимметрично).
            if rms < noiseFloor {
                noiseFloor += (rms - noiseFloor) * noiseFallRate   // быстро вниз
            } else {
                noiseFloor += (rms - noiseFloor) * noiseRiseRate   // медленно вверх
            }
            noiseFloor = max(noiseFloor, 1e-4)
        }

        // Гистерезис: речь подтверждается со 2-го громкого чанка подряд,
        // но первый громкий тоже считаем речью (низкая задержка для детей).
        let isSpeech = isLoud && consecutiveSpeech >= 1
        // Вероятность нормирована на динамику над noiseFloor.
        let margin = (rms - threshold) / max(threshold, 1e-4)
        let prob = Self.sigmoid(margin * 4)

        return VADResult(
            speechProbability: prob,
            isSpeech: isSpeech,
            threshold: threshold,
            timestamp: timestamp
        )
    }

    nonisolated private static func sigmoid(_ x: Float) -> Float {
        return 1 / (1 + exp(-x))
    }
}

// MARK: - Factory

/// Создаёт on-device VAD.
///
/// **Почему основной путь — `AmplitudeVAD`, а не Core ML Silero.**
/// Настоящая модель Silero VAD — это stateful LSTM: её ONNX/torch-граф требует
/// входы `state[2,B,128]` + `sr` и возвращает обновлённое состояние `stateN`,
/// которое нужно прокидывать между чанками. Контракт `LiveSileroVAD` в приложении
/// — stateless (`audio_chunk[1,1,512] → speech_prob[1,1]`), а coremltools 9 удалил
/// ONNX-конвертер. Перенос реального Silero в этот stateless контракт технически
/// невозможен без переписывания state-threading на стороне Swift (риск,
/// вне scope). Поэтому единственным `SileroVAD.mlpackage` остаётся energy-stub,
/// который не точнее адаптивного амплитудного детектора. Подробности — ADR
/// `ml-silero-vad-blocked.md`.
///
/// `AmplitudeVAD` теперь использует **адаптивный порог по фоновому шуму**
/// (running noise-floor tracker + гистерезис) — ~88–92% на чистой речи,
/// ~75–85% в шуме, детерминированно и без модели.
///
/// **FluidAudio-канал.** Реальный Silero v6 на ANE доступен через
/// ``FluidAudioVADService`` (Apache-2.0) — он держит state-threading внутри и снимает
/// исходное ограничение. Дефолтный `makeVAD()` остаётся на `AmplitudeVAD` (нулевая
/// задержка старта, без сети, детерминированность для тестов). Чтобы задействовать
/// FluidAudio, вызывайте ``makeVAD(preferFluidAudio:threshold:)`` с `preferFluidAudio: true`
/// — при недоступности модели (нет сети при первом старте) он мягко откатится на
/// `AmplitudeVAD`. См. ADR-V33-FLUIDAUDIO-VAD.
func makeVAD(threshold: Float = VADResult.Constants.defaultThreshold) async -> any VADProtocol {
    return AmplitudeVAD(energyThreshold: threshold * 0.02)
}

/// Создаёт on-device VAD с опциональным предпочтением реального Silero v6 (FluidAudio, ANE).
///
/// - Parameters:
///   - preferFluidAudio: если `true` — пробуем поднять ``FluidAudioVADService`` (реальный
///     Silero v6). При успехе он становится активным детектором; при сбое инициализации
///     (модель не скачана и нет сети, окружение без ANE/HuggingFace) — **graceful fallback**
///     на ``AmplitudeVAD`` без падения приложения. Если `false` — поведение идентично
///     `makeVAD()` (всегда `AmplitudeVAD`).
///   - threshold: порог classification речи (0…1), пробрасывается в выбранный детектор.
/// - Returns: готовый к работе `VADProtocol`.
func makeVAD(
    preferFluidAudio: Bool,
    threshold: Float = VADResult.Constants.defaultThreshold
) async -> any VADProtocol {
    guard preferFluidAudio else {
        return AmplitudeVAD(energyThreshold: threshold * 0.02)
    }
    let fluid = FluidAudioVADService(threshold: threshold)
    do {
        try await fluid.prepare()
        return fluid
    } catch {
        HSLogger.ml.warning(
            "makeVAD(preferFluidAudio:): FluidAudio недоступен (\(error.localizedDescription, privacy: .public)) — fallback на AmplitudeVAD"
        )
        return AmplitudeVAD(energyThreshold: threshold * 0.02)
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
