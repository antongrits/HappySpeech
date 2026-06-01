import Accelerate
@preconcurrency import AVFoundation
import FluidAudio
import Foundation
import OSLog

// MARK: - FluidAudioVADService

/// Реальный on-device VAD на базе **FluidAudio** (Apache-2.0) — обёртка над
/// production-grade Silero VAD v6 в формате Core ML, исполняемым на Apple Neural Engine.
///
/// ## Зачем
/// Самописный `LiveSileroVAD` не смог использовать настоящую модель Silero: это
/// stateful LSTM, требующая прокидывания скрытого состояния между чанками, что
/// невозможно в нашем stateless-контракте `[1,1,512] → [1,1]` (см. ADR-V32-SILERO-VAD-BLOCKED).
/// Поэтому основным детектором стал амплитудный `AmplitudeVAD` (~88–92% на чистой речи).
///
/// FluidAudio **решает** эту проблему: его `VadManager` (actor) держит state-threading
/// внутри (`VadState` hidden/cell/context), работает на ANE и даёт точность реального
/// Silero v6 (~95%+). `FluidAudioVADService` адаптирует его к нашему `VADProtocol`,
/// конвертируя per-chunk `VadResult` в наши `VADResult` / `VADSession`.
///
/// ## COPPA
/// Детское аудио **никогда не покидает устройство** — весь инференс on-device на ANE.
/// FluidAudio при первом запуске однократно скачивает CoreML-модель Silero v6 с
/// HuggingFace в `Application Support/` (это артефакт модели, не телеметрия — тот же
/// паттерн, что у WhisperKit). После кэширования сеть не нужна. Если модель недоступна
/// (нет сети при первом старте / окружение без HF) — инициализация бросает ошибку, и
/// фабрика `makeVAD` мягко откатывается на `AmplitudeVAD`. Никаких трекеров.
///
/// ## Контракт
/// FluidAudio обрабатывает чанками 4096 сэмплов (256 мс @ 16 кГц), а наш `VADProtocol`
/// определён на 512-сэмпловых чанках (32 мс). Поэтому:
/// - `processBuffer(_:)` — основной путь: передаёт весь буфер в `VadManager.process(_:)`,
///   получает массив 256-мс результатов и разворачивает их обратно в 512-сэмпловые
///   `VADResult` (каждый 256-мс результат «тиражируется» на 8 наших чанков с тем же
///   probability/isSpeech). Это сохраняет семантику `VADSession.speechDuration`.
/// - `detectSpeech(chunk:timestamp:)` — обрабатывает одиночный 512-сэмпловый чанк через
///   тот же движок (FluidAudio внутренне дополняет короткий чанк до 4096).
///
/// - SeeAlso: ``VADProtocol``, ``AmplitudeVAD``, ``makeVAD(preferFluidAudio:threshold:)``
actor FluidAudioVADService: VADProtocol {

    private let logger = Logger(subsystem: "HappySpeech", category: "FluidAudioVAD")
    private let threshold: Float
    private let chunkSize = VADResult.Constants.chunkSize        // 512
    private let targetSR = VADResult.Constants.sampleRate        // 16000

    /// Сколько наших 512-сэмпловых чанков укладывается в один 4096-сэмпловый чанк FluidAudio.
    private let subChunksPerFrame = FluidAudioVADService.fluidChunk / VADResult.Constants.chunkSize  // 8
    private static let fluidChunk = 4096

    private var manager: VadManager?

    /// - Parameter threshold: порог classification речи (0…1). По умолчанию совпадает с
    ///   нашим `defaultThreshold` 0.5; FluidAudio по умолчанию использует 0.85 для Silero v6,
    ///   но мы пробрасываем наш порог в `VadConfig`, чтобы поведение было предсказуемым.
    init(threshold: Float = VADResult.Constants.defaultThreshold) {
        self.threshold = threshold
    }

    /// Пытается инициализировать `VadManager` (загрузка/прогрев модели Silero v6).
    /// Бросает, если модель недоступна — это сигнал фабрике откатиться на `AmplitudeVAD`.
    func prepare() async throws {
        _ = try await loadManager()
    }

    // MARK: - VADProtocol

    func detectSpeech(
        chunk: AVAudioPCMBuffer,
        timestamp: TimeInterval
    ) async throws -> VADResult {
        guard let channelData = chunk.floatChannelData else {
            throw VADError.inferenceFailure("No channel data")
        }
        let frameCount = Int(chunk.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))

        let manager = try await loadManager()
        let results: [VadResult]
        do {
            results = try await manager.process(samples)
        } catch {
            throw VADError.inferenceFailure(error.localizedDescription)
        }

        // Для одиночного короткого чанка FluidAudio возвращает обычно один результат.
        guard let first = results.first else {
            throw VADError.inferenceFailure("Empty VAD result")
        }
        let prob = first.probability
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
        guard let channelData = buffer.floatChannelData else {
            throw VADError.inferenceFailure("No channel data")
        }
        let totalFrames = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: totalFrames))

        let manager = try await loadManager()
        let frameResults: [VadResult]
        do {
            frameResults = try await manager.process(samples)
        } catch {
            throw VADError.inferenceFailure(error.localizedDescription)
        }

        // Разворачиваем 256-мс результаты FluidAudio обратно в 512-сэмпловые VADResult,
        // чтобы сохранить контракт VADSession (timestamps в шаге 32 мс).
        var results: [VADResult] = []
        results.reserveCapacity(frameResults.count * subChunksPerFrame)

        for (frameIndex, frame) in frameResults.enumerated() {
            let prob = frame.probability
            let isSpeech = prob >= threshold
            for sub in 0 ..< subChunksPerFrame {
                let sampleOffset = frameIndex * Self.fluidChunk + sub * chunkSize
                if sampleOffset >= totalFrames { break }
                results.append(VADResult(
                    speechProbability: prob,
                    isSpeech: isSpeech,
                    threshold: threshold,
                    timestamp: TimeInterval(sampleOffset) / TimeInterval(targetSR)
                ))
            }
        }

        return VADSession(chunks: results)
    }

    // MARK: - Private

    private func loadManager() async throws -> VadManager {
        if let existing = manager {
            return existing
        }
        let config = VadConfig(
            defaultThreshold: threshold,
            debugMode: false,
            computeUnits: .cpuAndNeuralEngine
        )
        do {
            let created = try await VadManager(config: config)
            manager = created
            logger.info("FluidAudio VadManager (Silero v6, ANE) initialised")
            return created
        } catch {
            logger.warning(
                "FluidAudio VadManager init failed: \(error.localizedDescription, privacy: .public) — caller falls back to AmplitudeVAD"
            )
            throw VADError.modelNotFound
        }
    }
}
