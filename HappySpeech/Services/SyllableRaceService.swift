import AVFoundation
import Foundation
import OSLog

// MARK: - SyllableRaceServicing

/// Сервис «Скороговорки-ракеты» (диадохокинез) — пофайловый анализ ритмичного
/// повтора слогов ребёнком.
///
/// Слой Services поверх чистого DSP-ядра (`SyllableRateAnalyzer` +
/// `SyllableRateClassifier` в ML/Acoustics): принимает аудиофайл любого формата
/// AVFoundation, приводит к 16 кГц mono Float32 и возвращает детерминированную
/// оценку темпа, ритма и числа слогов.
///
/// ## COPPA
/// Полностью on-device: ни аудио, ни метрики не покидают устройство. Сервис
/// не хранит ничего сам — вызывающий решает, что персистить (только числа).
///
/// ## Честные границы
/// Игровая биообратная связь по акустике записи, не диагностика речи
/// (project guide §11). Пороги — документированные эвристики.
public protocol SyllableRaceServicing: Sendable {

    /// Анализирует записанную попытку слогового ряда.
    /// - Parameters:
    ///   - url: аудиофайл попытки (m4a/wav — любой читаемый AVAudioFile).
    ///   - sequence: целевой слоговой ряд (для нормирования числа слогов).
    ///   - childAge: возраст ребёнка (для возрастных ориентиров темпа).
    /// - Returns: оценка попытки. Если ряд не распознан — честный вердикт
    ///   `.notDetected`, без фабрикации.
    /// - Throws: `AppError.audioFormatUnsupported`, если файл не читается.
    func analyzeAttempt(
        url: URL,
        sequence: DDKSequence,
        childAge: Int
    ) async throws -> DDKEvaluation
}

// MARK: - LiveSyllableRaceService

/// Боевая реализация: AVAudioFile → ресемплинг 16 кГц mono → DSP-ядро.
public actor LiveSyllableRaceService: SyllableRaceServicing {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SyllableRace")

    public init() {}

    public func analyzeAttempt(
        url: URL,
        sequence: DDKSequence,
        childAge: Int
    ) async throws -> DDKEvaluation {
        let pcm = try Self.loadPCM16kMono(url: url)
        let measurement = SyllableRateAnalyzer.analyze(pcm: pcm)
        let evaluation = SyllableRateClassifier.evaluate(
            measurement: measurement,
            sequence: sequence,
            childAge: childAge
        )

        let rate = String(format: "%.2f", evaluation.syllablesPerSecond)
        logger.info(
            """
            SyllableRace: verdict=\(evaluation.verdict.rawValue, privacy: .public) \
            rate=\(rate, privacy: .public)/s syl=\(evaluation.detectedSyllables)/\(evaluation.targetSyllables)
            """
        )
        return evaluation
    }

    // MARK: - Audio loading

    /// Читает аудиофайл и приводит к 16 кГц mono Float32.
    static func loadPCM16kMono(url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let sourceFormat = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount)
        else {
            throw AppError.audioFormatUnsupported
        }
        try file.read(into: sourceBuffer)

        let targetRate = SyllableRateAnalyzer.expectedSampleRate
        // Уже нужный формат — отдаём без конвертации.
        if sourceFormat.sampleRate == targetRate,
           sourceFormat.channelCount == 1,
           sourceFormat.commonFormat == .pcmFormatFloat32,
           let channel = sourceBuffer.floatChannelData?[0] {
            return Array(UnsafeBufferPointer(start: channel, count: Int(sourceBuffer.frameLength)))
        }

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetRate,
            channels: 1,
            interleaved: false
        ), let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw AppError.audioFormatUnsupported
        }

        let ratio = targetRate / sourceFormat.sampleRate
        let targetCapacity = AVAudioFrameCount((Double(sourceBuffer.frameLength) * ratio).rounded(.up) + 64)
        guard let targetBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: targetCapacity
        ) else {
            throw AppError.audioFormatUnsupported
        }

        // AVAudioConverterInputBlock — @Sendable, но вызывается синхронно на этом
        // же потоке до возврата из convert(); состояние подачи (флаг + non-Sendable
        // буфер) безопасно держать в @unchecked Sendable-боксе.
        let feed = SyllableConverterFeed(buffer: sourceBuffer)
        var conversionError: NSError?
        converter.convert(to: targetBuffer, error: &conversionError) { _, status in
            if feed.consumed {
                status.pointee = .endOfStream
                return nil
            }
            feed.consumed = true
            status.pointee = .haveData
            return feed.buffer
        }
        if let conversionError {
            throw AppError.audioRecordingFailed(conversionError.localizedDescription)
        }
        guard let channel = targetBuffer.floatChannelData?[0] else {
            throw AppError.audioFormatUnsupported
        }
        return Array(UnsafeBufferPointer(start: channel, count: Int(targetBuffer.frameLength)))
    }
}

// MARK: - SyllableConverterFeed

/// Состояние одноразовой подачи для `AVAudioConverterInputBlock`.
///
/// Блок ввода конвертера помечен `@Sendable`, но фактически вызывается синхронно
/// на вызывающем потоке до возврата из `convert(to:error:)` — реальной
/// конкурентности нет. Бокс позволяет держать изменяемый флаг и non-Sendable
/// `AVAudioPCMBuffer` без предупреждений Swift 6 concurrency.
private final class SyllableConverterFeed: @unchecked Sendable {
    var consumed = false
    let buffer: AVAudioPCMBuffer
    init(buffer: AVAudioPCMBuffer) { self.buffer = buffer }
}

// MARK: - MockSyllableRaceService

/// Детерминированный mock для preview/тестов — без чтения файлов и DSP.
public actor MockSyllableRaceService: SyllableRaceServicing {

    /// Заранее заданная последовательность ответов (по кругу).
    private let scripted: [DDKEvaluation]
    private var cursor = 0
    /// Список запросов — для проверок в тестах.
    public private(set) var receivedSequenceIds: [String] = []

    public init(scripted: [DDKEvaluation] = [MockSyllableRaceService.defaultEvaluation]) {
        self.scripted = scripted.isEmpty ? [Self.defaultEvaluation] : scripted
    }

    public static let defaultEvaluation = DDKEvaluation(
        syllablesPerSecond: 4.6,
        steadiness: 0.88,
        detectedSyllables: 8,
        targetSyllables: 8,
        verdict: .fastSteady,
        flags: [],
        stars: 3,
        measurement: SyllableRateMeasurement(
            syllableCount: 8,
            syllablesPerSecond: 4.6,
            voicedDurationSec: 1.52,
            intervalCV: 0.09,
            meanIntervalSec: 0.217,
            peakRMS: 0.18
        )
    )

    public func analyzeAttempt(
        url: URL,
        sequence: DDKSequence,
        childAge: Int
    ) async throws -> DDKEvaluation {
        receivedSequenceIds.append(sequence.id)
        let evaluation = scripted[cursor % scripted.count]
        cursor += 1
        return evaluation
    }
}
