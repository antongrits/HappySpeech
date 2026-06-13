import AVFoundation
import Foundation
import OSLog

// MARK: - AcousticMirrorServicing

/// Сервис «Акустического зеркала» — пофайловый акустический анализ попытки
/// ребёнка произнести (потянуть) свистящий/шипящий звук.
///
/// Слой Services поверх чистого DSP-ядра (`SibilantAcousticsAnalyzer` +
/// `SibilantContinuumClassifier` в ML/Acoustics): принимает аудиофайл любого
/// формата AVFoundation, приводит к 16 кГц mono Float32 и возвращает
/// детерминированную оценку положения звука на континууме «С ↔ Ш».
///
/// ## COPPA
/// Полностью on-device: ни аудио, ни метрики не покидают устройство. Сервис
/// не хранит ничего сам — вызывающий решает, что персистить (только числа).
///
/// ## Честные границы
/// Игровая биообратная связь по акустике записи, не диагностика речи
/// (project guide §11). Пороги — документированные эвристики.
public protocol AcousticMirrorServicing: Sendable {

    /// Анализирует записанную попытку.
    /// - Parameters:
    ///   - url: аудиофайл попытки (m4a/wav — любой читаемый AVAudioFile).
    ///   - targetSound: целевой звук (кириллица: С/З/Ц/Ш/Ж/Щ/Ч).
    /// - Returns: оценка попытки. Если файл не содержит фрикативного шума —
    ///   честный вердикт `.noFrication`, без фабрикации.
    /// - Throws: `AppError.audioFormatUnsupported`, если файл не читается, либо
    ///   `AppError.mlInferenceFailed`, если `targetSound` не сибилянт.
    func analyzeAttempt(url: URL, targetSound: String) async throws -> SibilantEvaluation
}

// MARK: - LiveAcousticMirrorService

/// Боевая реализация: AVAudioFile → ресемплинг 16 кГц mono → DSP-ядро.
public actor LiveAcousticMirrorService: AcousticMirrorServicing {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "AcousticMirror")

    public init() {}

    public func analyzeAttempt(url: URL, targetSound: String) async throws -> SibilantEvaluation {
        guard let pole = SibilantPole.pole(forTargetSound: targetSound) else {
            throw AppError.mlInferenceFailed("AcousticMirror: звук '\(targetSound)' не является сибилянтом")
        }

        let pcm = try Self.loadPCM16kMono(url: url)
        let measurement = SibilantAcousticsAnalyzer.analyze(pcm: pcm)
        let evaluation = SibilantContinuumClassifier.evaluate(
            measurement: measurement,
            targetPole: pole
        )

        let centroid = measurement.map { String(format: "%.0f", $0.centroidHz) } ?? "—"
        let position = String(format: "%.2f", evaluation.continuumPosition)
        logger.info(
            """
            AcousticMirror: verdict=\(evaluation.verdict.rawValue, privacy: .public) \
            pos=\(position, privacy: .public) centroid=\(centroid, privacy: .public)Hz
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

        let targetRate = SibilantAcousticsAnalyzer.expectedSampleRate
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
        let feed = ConverterSingleShotFeed(buffer: sourceBuffer)
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

// MARK: - ConverterSingleShotFeed

/// Состояние одноразовой подачи для `AVAudioConverterInputBlock`.
///
/// Блок ввода конвертера помечен `@Sendable`, но фактически вызывается
/// синхронно на вызывающем потоке до возврата из `convert(to:error:)` —
/// реальной конкурентности нет. Бокс позволяет держать изменяемый флаг и
/// non-Sendable `AVAudioPCMBuffer` без предупреждений Swift 6 concurrency.
private final class ConverterSingleShotFeed: @unchecked Sendable {
    var consumed = false
    let buffer: AVAudioPCMBuffer
    init(buffer: AVAudioPCMBuffer) { self.buffer = buffer }
}

// MARK: - MockAcousticMirrorService

/// Детерминированный mock для preview/тестов — без чтения файлов и DSP.
public actor MockAcousticMirrorService: AcousticMirrorServicing {

    /// Заранее заданная последовательность ответов (по кругу).
    private let scripted: [SibilantEvaluation]
    private var cursor = 0
    /// Список запросов — для проверок в тестах.
    public private(set) var receivedTargetSounds: [String] = []

    public init(scripted: [SibilantEvaluation] = [MockAcousticMirrorService.defaultEvaluation]) {
        self.scripted = scripted.isEmpty ? [Self.defaultEvaluation] : scripted
    }

    public static let defaultEvaluation = SibilantEvaluation(
        continuumPosition: 0.82,
        verdict: .onTarget,
        flags: [],
        stars: 3,
        measurement: SibilantMeasurement(
            centroidHz: 6_900,
            spreadHz: 1_400,
            highBandShare: 0.62,
            fricationDuration: 0.9,
            peakRMS: 0.21,
            frameCount: 56
        ),
        targetPole: .whistling
    )

    public func analyzeAttempt(url: URL, targetSound: String) async throws -> SibilantEvaluation {
        receivedTargetSounds.append(targetSound)
        let evaluation = scripted[cursor % scripted.count]
        cursor += 1
        return evaluation
    }
}
