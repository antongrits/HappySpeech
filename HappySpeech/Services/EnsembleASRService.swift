import AVFoundation
import Foundation
import OSLog

// MARK: - EnsembleASRTier

/// Уровень ансамбля ASR — определяет, какие модели участвуют в голосовании.
///
/// Tier A (детский): только on-device модели (RussianPhonemeClassifier + PronunciationScorer).
/// COPPA-обязательно: никогда не отправляет аудио в сеть из детского контура.
///
/// Tier B (родитель/специалист): полная цепочка включая WhisperKit.
public enum EnsembleASRDetailTier: String, Sendable {
    /// On-device только: RussianPhonemeClassifier + PronunciationScorer (детский контур).
    case a
    /// Полная точность: Tier A + WhisperKit tiny/base/small (родитель/специалист).
    case b
}

// MARK: - EnsembleASRResult

/// Результат ансамблевого ASR-распознавания.
public struct EnsembleASRResult: Sendable {
    /// Итоговый транскрипт — взвешенное голосование моделей.
    public let transcript: String
    /// Точность произношения по фонемам (0.0–1.0), из PronunciationScorer.
    public let phonemeAccuracy: Float
    /// Итоговая уверенность ансамбля (0.0–1.0).
    public let confidence: Float
    /// Тир, который был использован при распознавании.
    public let detectedTier: EnsembleASRDetailTier
    /// Время обработки в миллисекундах.
    public let processingTimeMs: Int
}

// MARK: - EnsembleASRServiceProtocol

/// Протокол ансамблевого ASR-сервиса.
///
/// Комбинирует несколько ML-моделей через взвешенное голосование.
/// Детский контур всегда использует только Tier A (on-device).
///
/// ## COPPA
/// - Tier A: только CoreML на устройстве, нет сетевых вызовов.
/// - Tier B: использование Tier B разрешено только из parent/specialist контекста.
public protocol EnsembleASRServiceProtocol: Sendable {

    /// Распознаёт речь из аудиофайла.
    /// - Parameters:
    ///   - url: URL аудиофайла (16kHz mono, WAV/M4A)
    ///   - tier: уровень ансамбля (.a — детский, .b — родительский/специалист)
    /// - Returns: результат ансамблевого распознавания
    func recognize(url: URL, tier: EnsembleASRDetailTier) async throws -> EnsembleASRResult

    /// Подготавливает модели к работе (вызывать заранее для уменьшения latency).
    func warmUp(tier: EnsembleASRDetailTier) async
}

// MARK: - LiveEnsembleASRService

/// Живая реализация ансамблевого ASR.
///
/// Пайплайн Tier A:
/// 1. `RussianPhonemeClassifier` (CoreML) — фонемное распознавание
/// 2. `PronunciationScorer` (CoreML) — оценка произношения
/// 3. Взвешенное голосование (веса: фонемный классификатор 0.6, скорер 0.4)
///
/// Пайплайн Tier B (дополнительно к Tier A):
/// 4. `WhisperKit` (WhisperKit wrapper) — полный транскрипт
/// 5. Взвешенное голосование (веса: Whisper 0.7, фонемный 0.2, скорер 0.1)
///
/// ## Веса голосования
/// Подобраны эмпирически на val-сете русской детской речи (v15 Block B):
/// - Whisper достаточно точен для текстового транскрипта.
/// - PhonemeClassifier точнее в sub-word фонемном выравнивании.
/// - PronunciationScorer даёт calibrated probability (не CTC logits).
public final class LiveEnsembleASRService: EnsembleASRServiceProtocol, @unchecked Sendable {

    // MARK: - Dependencies

    private let whisperASR: any ASRService
    private let phonemeClassifier: any PhonemeAnalysisService
    private let pronunciationScorer: any PronunciationScorerService

    // MARK: - Logger

    private let logger = Logger(subsystem: "ru.happyspeech", category: "EnsembleASR")

    // MARK: - Weights

    /// Веса для Tier A (без Whisper).
    private static let tierAPhonemeWeight: Float = 0.65
    private static let tierAScorerWeight: Float = 0.35

    /// Веса для Tier B (с Whisper).
    private static let tierBWhisperWeight: Float = 0.70
    private static let tierBPhonemeWeight: Float = 0.20
    private static let tierBScorerWeight: Float = 0.10

    // MARK: - Init

    public init(
        whisperASR: any ASRService,
        phonemeClassifier: any PhonemeAnalysisService,
        pronunciationScorer: any PronunciationScorerService
    ) {
        self.whisperASR = whisperASR
        self.phonemeClassifier = phonemeClassifier
        self.pronunciationScorer = pronunciationScorer
    }

    // MARK: - EnsembleASRServiceProtocol

    public func recognize(url: URL, tier: EnsembleASRDetailTier) async throws -> EnsembleASRResult {
        let start = Date()
        logger.debug("EnsembleASR: начало распознавания, tier=\(tier.rawValue)")

        switch tier {
        case .a:
            return try await recognizeTierA(url: url, start: start)
        case .b:
            return try await recognizeTierB(url: url, start: start)
        }
    }

    public func warmUp(tier: EnsembleASRDetailTier) async {
        if tier == .b {
            try? await whisperASR.loadModel(tier: .kidOnDevice)
        }
        logger.debug("EnsembleASR: warmUp завершён, tier=\(tier.rawValue)")
    }

    // MARK: - Tier A: on-device только

    private func recognizeTierA(url: URL, start: Date) async throws -> EnsembleASRResult {
        // Загружаем PCM данные для CoreML-моделей
        let pcmData = try loadPCMData(from: url)

        // PhonemeClassifier — фонемное распознавание
        async let phonemeTask = phonemeClassifier.analyze(audio: pcmData, expectedWord: "")
        // PronunciationScorer — оценка произношения из audio URL
        async let scorerTask = pronunciationScorer.score(audioURL: url, targetSound: "")

        let (phonemeResult, scorerResult) = try await (phonemeTask, scorerTask)

        // Собираем транскрипт из предсказанных фонем
        let phonemeTranscript = phonemeResult.predictedPhonemes
            .prefix(20)
            .map { $0.predictedIPA }
            .joined()

        // Взвешенное голосование уверенности
        let phonemeConfidence = Float(phonemeResult.overallScore)
        let scorerConfidence = Float(scorerResult.value)

        let ensembleConfidence = Self.tierAPhonemeWeight * phonemeConfidence
            + Self.tierAScorerWeight * scorerConfidence

        let elapsed = Int(Date().timeIntervalSince(start) * 1000)
        logger.info("EnsembleASR Tier A: confidence=\(ensembleConfidence), elapsed=\(elapsed)мс")

        return EnsembleASRResult(
            transcript: phonemeTranscript,
            phonemeAccuracy: scorerConfidence,
            confidence: ensembleConfidence,
            detectedTier: .a,
            processingTimeMs: elapsed
        )
    }

    // MARK: - Tier B: Whisper + on-device

    private func recognizeTierB(url: URL, start: Date) async throws -> EnsembleASRResult {
        let pcmData = try loadPCMData(from: url)

        // Запускаем все три модели параллельно
        async let whisperTask = whisperASR.transcribe(url: url)
        async let phonemeTask = phonemeClassifier.analyze(audio: pcmData, expectedWord: "")
        async let scorerTask = pronunciationScorer.score(audioURL: url, targetSound: "")

        let (whisperResult, phonemeResult, scorerResult) = try await (whisperTask, phonemeTask, scorerTask)

        // Whisper даёт полный текстовый транскрипт
        let transcript = whisperResult.transcript.isEmpty
            ? phonemeResult.predictedPhonemes.prefix(20).map { $0.predictedIPA }.joined()
            : whisperResult.transcript

        // Взвешенное голосование
        let whisperConfidence = Float(whisperResult.confidence)
        let phonemeConfidence = Float(phonemeResult.overallScore)
        let scorerConfidence = Float(scorerResult.value)

        let ensembleConfidence = Self.tierBWhisperWeight * whisperConfidence
            + Self.tierBPhonemeWeight * phonemeConfidence
            + Self.tierBScorerWeight * scorerConfidence

        let elapsed = Int(Date().timeIntervalSince(start) * 1000)
        logger.info("EnsembleASR Tier B: whisper=\(whisperConfidence), phoneme=\(phonemeConfidence), scorer=\(scorerConfidence), ensemble=\(ensembleConfidence), elapsed=\(elapsed)мс")

        return EnsembleASRResult(
            transcript: transcript,
            phonemeAccuracy: scorerConfidence,
            confidence: ensembleConfidence,
            detectedTier: .b,
            processingTimeMs: elapsed
        )
    }

    // MARK: - PCM Loading

    /// Загружает аудиофайл как Float32 PCM Data для CoreML-моделей.
    private func loadPCMData(from url: URL) throws -> Data {
        let audioFile = try AVAudioFile(forReading: url)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: AVAudioFrameCount(audioFile.length)
        ) else {
            throw AppError.audioFormatUnsupported
        }
        try audioFile.read(into: buffer)
        guard let channelData = buffer.floatChannelData?[0] else {
            throw AppError.audioFormatUnsupported
        }
        let count = Int(buffer.frameLength)
        return Data(bytes: channelData, count: count * MemoryLayout<Float>.size)
    }
}

// MARK: - MockEnsembleASRService

/// Mock-реализация для unit-тестов и SwiftUI Preview.
///
/// Всегда возвращает детерминированный результат с высокой уверенностью.
/// Использует Tier A (on-device) по умолчанию, COPPA-безопасен.
public final class MockEnsembleASRService: EnsembleASRServiceProtocol, @unchecked Sendable {

    public var mockTranscript: String
    public var mockPhonemeAccuracy: Float
    public var mockConfidence: Float
    public var mockProcessingTimeMs: Int

    public init(
        transcript: String = "рыба",
        phonemeAccuracy: Float = 0.88,
        confidence: Float = 0.91,
        processingTimeMs: Int = 45
    ) {
        self.mockTranscript = transcript
        self.mockPhonemeAccuracy = phonemeAccuracy
        self.mockConfidence = confidence
        self.mockProcessingTimeMs = processingTimeMs
    }

    public func recognize(url: URL, tier: EnsembleASRDetailTier) async throws -> EnsembleASRResult {
        EnsembleASRResult(
            transcript: mockTranscript,
            phonemeAccuracy: mockPhonemeAccuracy,
            confidence: mockConfidence,
            detectedTier: tier,
            processingTimeMs: mockProcessingTimeMs
        )
    }

    public func warmUp(tier: EnsembleASRDetailTier) async {}
}
