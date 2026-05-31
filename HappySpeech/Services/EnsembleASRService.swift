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
    ///   - expectedWord: ожидаемое слово урока (для фонемного выравнивания и
    ///     word-list biasing). Пустая строка, если контекст не известен.
    ///   - targetSound: целевой звук группы (`whistling` / `hissing` / `sonants` /
    ///     `velar`) для маршрутизации PronunciationScorer. Пустая строка отключает скорер.
    /// - Returns: результат ансамблевого распознавания
    func recognize(
        url: URL,
        tier: EnsembleASRDetailTier,
        expectedWord: String,
        targetSound: String
    ) async throws -> EnsembleASRResult

    /// Подготавливает модели к работе (вызывать заранее для уменьшения latency).
    func warmUp(tier: EnsembleASRDetailTier) async

    /// Считает phonetic accuracy через сравнение IPA-последовательностей.
    ///
    /// Детерминированный, локальный (`COPPA-safe`) скоринг через
    /// ``RussianG2P/phoneticSimilarity(_:_:)`` с учётом артикуляционного
    /// расстояния между фонемами (``IPADictionary/articulationDistance(_:_:)``).
    ///
    /// - Parameters:
    ///   - child: предсказанные ребёнком фонемы (например, из ``RussianPhonemeClassifier``).
    ///   - reference: эталонные фонемы из G2P-транскрипции слова.
    /// - Returns: значение в `[0, 1]`, где 1.0 — идеальное совпадение.
    func phoneticAccuracy(child: [String], reference: [String]) -> Double
}

// MARK: - EnsembleASRServiceProtocol convenience

public extension EnsembleASRServiceProtocol {

    /// Обратная совместимость: распознавание без контекста слова/звука.
    /// Делегирует основному методу с пустыми контекстными параметрами.
    func recognize(url: URL, tier: EnsembleASRDetailTier) async throws -> EnsembleASRResult {
        try await recognize(url: url, tier: tier, expectedWord: "", targetSound: "")
    }
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
/// 5. `Wav2Vec2` (CTC фонемный декодер, ~302 MB) — четвёртый голос фонемной
///    уверенности (только Tier B, родитель/специалист; модель тяжёлая).
/// 6. Взвешенное голосование (веса: Whisper 0.6, фонемный 0.18, скорер 0.1, Wav2Vec2 0.12)
///
/// ## Веса голосования
/// Подобраны эмпирически на val-сете русской детской речи (v15 Block B):
/// - Whisper достаточно точен для текстового транскрипта.
/// - PhonemeClassifier точнее в sub-word фонемном выравнивании.
/// - PronunciationScorer даёт calibrated probability (не CTC logits).
/// - Wav2Vec2 CTC добавляет независимую фонемную оценку — снижает дисперсию.
public final class LiveEnsembleASRService: EnsembleASRServiceProtocol, @unchecked Sendable {

    // MARK: - Dependencies

    private let whisperASR: any ASRService
    private let phonemeClassifier: any PhonemeAnalysisService
    private let pronunciationScorer: any PronunciationScorerService
    /// Tier B-only: CTC фонемный декодер. Опционален — при отсутствии ансамбль
    /// собирается из трёх голосов (back-compat). НИКОГДА не используется в Tier A
    /// (детский контур), т.к. модель тяжёлая и не нужна для on-device скоринга.
    private let wav2Vec2: (any Wav2Vec2Service)?

    // MARK: - Logger

    private let logger = Logger(subsystem: "ru.happyspeech", category: "EnsembleASR")

    // MARK: - Weights

    /// Веса для Tier A (без Whisper).
    private static let tierAPhonemeWeight: Float = 0.65
    private static let tierAScorerWeight: Float = 0.35

    /// Веса для Tier B (с Whisper, без Wav2Vec2).
    private static let tierBWhisperWeight: Float = 0.70
    private static let tierBPhonemeWeight: Float = 0.20
    private static let tierBScorerWeight: Float = 0.10

    /// Веса для Tier B (с Whisper + Wav2Vec2 CTC, четыре голоса).
    private static let tierBWavWhisperWeight: Float = 0.60
    private static let tierBWavPhonemeWeight: Float = 0.18
    private static let tierBWavScorerWeight: Float = 0.10
    private static let tierBWavCTCWeight: Float = 0.12

    // MARK: - Init

    public init(
        whisperASR: any ASRService,
        phonemeClassifier: any PhonemeAnalysisService,
        pronunciationScorer: any PronunciationScorerService,
        wav2Vec2: (any Wav2Vec2Service)? = nil
    ) {
        self.whisperASR = whisperASR
        self.phonemeClassifier = phonemeClassifier
        self.pronunciationScorer = pronunciationScorer
        self.wav2Vec2 = wav2Vec2
    }

    // MARK: - EnsembleASRServiceProtocol

    public func recognize(
        url: URL,
        tier: EnsembleASRDetailTier,
        expectedWord: String,
        targetSound: String
    ) async throws -> EnsembleASRResult {
        let start = Date()
        logger.debug("EnsembleASR: начало распознавания, tier=\(tier.rawValue)")

        switch tier {
        case .a:
            return try await recognizeTierA(
                url: url,
                start: start,
                expectedWord: expectedWord,
                targetSound: targetSound
            )
        case .b:
            return try await recognizeTierB(
                url: url,
                start: start,
                expectedWord: expectedWord,
                targetSound: targetSound
            )
        }
    }

    public func warmUp(tier: EnsembleASRDetailTier) async {
        if tier == .b {
            // Tier B — родительский/специалистский контур: прогреваем модель
            // полной точности (.parentQuality), а не kid-tier whisper-tiny.
            try? await whisperASR.loadModel(tier: .parentQuality)
        }
        logger.debug("EnsembleASR: warmUp завершён, tier=\(tier.rawValue)")
    }

    /// Phonetic accuracy через ``RussianG2P`` + взвешивание по
    /// ``IPADictionary/articulationDistance(_:_:)``.
    ///
    /// Шаги:
    /// 1. Считается базовая Левенштейн-similarity (символьная).
    /// 2. Если массивы той же длины — корректируем штраф за каждую замену
    ///    через `articulationDistance` (близкая замена `s` → `sʲ` штрафуется
    ///    меньше, чем `s` → `r`).
    public func phoneticAccuracy(child: [String], reference: [String]) -> Double {
        let g2p = RussianG2P()
        let baseSimilarity = g2p.phoneticSimilarity(reference, child)

        guard child.count == reference.count, !child.isEmpty else {
            return baseSimilarity
        }

        // Контекстная корректировка: штраф за замену взвешен на articulationDistance
        var totalDistance: Double = 0
        for i in 0 ..< reference.count {
            totalDistance += IPADictionary.articulationDistance(reference[i], child[i])
        }
        let avgDistance = totalDistance / Double(reference.count)
        let articulationSimilarity = 1.0 - avgDistance

        // Взвешенное среднее: 0.5 базовая + 0.5 контекстная
        return 0.5 * baseSimilarity + 0.5 * articulationSimilarity
    }

    // MARK: - Tier A: on-device только

    private func recognizeTierA(
        url: URL,
        start: Date,
        expectedWord: String,
        targetSound: String
    ) async throws -> EnsembleASRResult {
        // Загружаем PCM данные для CoreML-моделей
        let pcmData = try loadPCMData(from: url)

        // PhonemeClassifier — фонемное распознавание (с контекстом ожидаемого слова)
        async let phonemeTask = phonemeClassifier.analyze(audio: pcmData, expectedWord: expectedWord)
        // PronunciationScorer — оценка произношения из audio URL (с целевым звуком)
        async let scorerTask = pronunciationScorer.score(audioURL: url, targetSound: targetSound)

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

    // MARK: - Tier B: Whisper + on-device (+ опц. Wav2Vec2 CTC)

    private func recognizeTierB(
        url: URL,
        start: Date,
        expectedWord: String,
        targetSound: String
    ) async throws -> EnsembleASRResult {
        let pcmData = try loadPCMData(from: url)

        // Запускаем три обязательных голоса параллельно (с контекстом слова/звука)
        async let whisperTask = whisperASR.transcribe(url: url)
        async let phonemeTask = phonemeClassifier.analyze(audio: pcmData, expectedWord: expectedWord)
        async let scorerTask = pronunciationScorer.score(audioURL: url, targetSound: targetSound)

        let (whisperResult, phonemeResult, scorerResult) = try await (whisperTask, phonemeTask, scorerTask)

        // Четвёртый голос (Wav2Vec2 CTC) — только если зависимость подключена.
        // Tier B (parent/specialist) — тяжёлая модель допустима. Ошибка декодера
        // деградирует gracefully до трёхголосого ансамбля.
        let ctcConfidence: Float? = await wav2Vec2CTCConfidence(pcmData: pcmData)

        // Whisper даёт полный текстовый транскрипт
        let transcript = whisperResult.transcript.isEmpty
            ? phonemeResult.predictedPhonemes.prefix(20).map { $0.predictedIPA }.joined()
            : whisperResult.transcript

        let whisperConfidence = Float(whisperResult.confidence)
        let phonemeConfidence = Float(phonemeResult.overallScore)
        let scorerConfidence = Float(scorerResult.value)

        let ensembleConfidence: Float
        if let ctcConfidence {
            // Четырёхголосое голосование (с Wav2Vec2).
            ensembleConfidence = Self.tierBWavWhisperWeight * whisperConfidence
                + Self.tierBWavPhonemeWeight * phonemeConfidence
                + Self.tierBWavScorerWeight * scorerConfidence
                + Self.tierBWavCTCWeight * ctcConfidence
        } else {
            // Трёхголосое голосование (Wav2Vec2 недоступен).
            ensembleConfidence = Self.tierBWhisperWeight * whisperConfidence
                + Self.tierBPhonemeWeight * phonemeConfidence
                + Self.tierBScorerWeight * scorerConfidence
        }

        let elapsed = Int(Date().timeIntervalSince(start) * 1000)
        let ctcLog = ctcConfidence.map { String(format: "%.2f", $0) } ?? "—"
        logger.info(
            "EnsembleASR B w:\(whisperConfidence) ph:\(phonemeConfidence) sc:\(scorerConfidence) ctc:\(ctcLog) ens:\(ensembleConfidence) \(elapsed)мс"
        )

        return EnsembleASRResult(
            transcript: transcript,
            phonemeAccuracy: scorerConfidence,
            confidence: ensembleConfidence,
            detectedTier: .b,
            processingTimeMs: elapsed
        )
    }

    /// Запускает Wav2Vec2 CTC-декодер и возвращает среднюю уверенность фонем.
    /// `nil`, если зависимость не подключена или модель не загрузилась —
    /// ансамбль gracefully сводится к трём голосам.
    private func wav2Vec2CTCConfidence(pcmData: Data) async -> Float? {
        guard let wav2Vec2 else { return nil }
        do {
            let result = try await wav2Vec2.transcribe(audio: pcmData)
            return Float(result.averageConfidence)
        } catch {
            logger.warning("EnsembleASR: Wav2Vec2 CTC недоступен (\(error.localizedDescription)) — три голоса")
            return nil
        }
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

    /// Последний `expectedWord`, переданный в `recognize` — для проверок в тестах.
    public private(set) var lastExpectedWord: String = ""
    /// Последний `targetSound`, переданный в `recognize` — для проверок в тестах.
    public private(set) var lastTargetSound: String = ""
    /// Последний `tier`, переданный в `recognize` — для проверок в тестах.
    public private(set) var lastTier: EnsembleASRDetailTier?

    public func recognize(
        url: URL,
        tier: EnsembleASRDetailTier,
        expectedWord: String,
        targetSound: String
    ) async throws -> EnsembleASRResult {
        lastExpectedWord = expectedWord
        lastTargetSound = targetSound
        lastTier = tier
        return EnsembleASRResult(
            transcript: mockTranscript,
            phonemeAccuracy: mockPhonemeAccuracy,
            confidence: mockConfidence,
            detectedTier: tier,
            processingTimeMs: mockProcessingTimeMs
        )
    }

    public func warmUp(tier: EnsembleASRDetailTier) async {}

    public func phoneticAccuracy(child: [String], reference: [String]) -> Double {
        guard !reference.isEmpty else { return 1.0 }
        let matches = zip(child, reference).reduce(into: 0) { acc, pair in
            if pair.0 == pair.1 { acc += 1 }
        }
        return Double(matches) / Double(reference.count)
    }
}
