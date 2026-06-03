@preconcurrency import AVFoundation
import Foundation
import OSLog

// MARK: - SpeechPreflightDecision

/// Решение пред-проверки записи перед запуском тяжёлого ASR (WhisperKit).
public enum SpeechPreflightDecision: Sendable, Equatable {
    /// Уверенная тишина — ASR можно пропустить (вернуть пустой результат).
    case likelySilent
    /// Возможна речь (в т.ч. искажённая/тихая детская) — запускать ASR.
    case proceed
}

// MARK: - SpeechPreflightGating

/// Лёгкая пред-проверка аудиофайла перед ASR.
///
/// Закрывает «мёртвый периметр» аудита (#4/#5): реальный VAD (Silero v6 через
/// FluidAudio, ANE) и `SoundClassifier` (CoreML) теперь **исполняются в боевом
/// recording→ASR пайплайне**, а не лежат мёртвым весом.
///
/// **Намеренно консервативна.** Логопедическая речь часто тихая/искажённая, поэтому
/// гейт коротит ASR **только** при уверенной тишине, когда **оба** канала согласны:
///   * `VADSession.hasSpeech == false` (реальный Silero v6), и
///   * `SoundClassifier` → `.silence` с высокой уверенностью.
/// При любом сомнении (шум/неясно/частичная речь) — `.proceed`. Так мы экономим
/// дорогой проход WhisperKit на чистой тишине, **никогда не отбрасывая** реальную
/// (даже искажённую) детскую речь.
public protocol SpeechPreflightGating: Sendable {
    /// Анализирует записанный файл и решает, запускать ли ASR.
    /// Никогда не бросает: при любой ошибке/недоступности модели → `.proceed`
    /// (fail-open — лучше прогнать ASR, чем потерять речь ребёнка).
    func evaluate(url: URL) async -> SpeechPreflightDecision
}

// MARK: - LiveSpeechPreflightGate

public final class LiveSpeechPreflightGate: SpeechPreflightGating, @unchecked Sendable {

    private let audioAnalysis: any AudioAnalysisService
    private let logger = Logger(subsystem: "ru.happyspeech", category: "SpeechPreflight")
    /// Кэш VAD-инстанса: создаём реальный Silero v6 (FluidAudio) один раз и
    /// переиспользуем между транскрипциями (иначе модель грузилась бы каждый раз).
    private let vadBox = VADBox()

    /// Минимальная уверенность класса `.silence`, при которой доверяем «тишине».
    private let silenceConfidenceFloor: Float = 0.75
    /// Целевая частота для VAD/классификатора.
    private let targetSampleRate: Double = 16_000

    public init(audioAnalysis: any AudioAnalysisService = LiveAudioAnalysisService()) {
        self.audioAnalysis = audioAnalysis
    }

    public func evaluate(url: URL) async -> SpeechPreflightDecision {
        guard let buffer = Self.loadMonoBuffer(url: url, targetSampleRate: targetSampleRate) else {
            // Не смогли прочитать файл — не рискуем, пропускаем дальше в ASR.
            return .proceed
        }

        // 1. Реальный Silero v6 VAD (FluidAudio, ANE). При недоступности модели
        //    фабрика мягко отдаёт AmplitudeVAD — оба пути дают корректный hasSpeech.
        let vad = await vadBox.shared()
        let vadHasSpeech: Bool
        do {
            let session = try await vad.processBuffer(buffer)
            vadHasSpeech = session.hasSpeech
        } catch {
            // VAD недоступен/ошибка — fail-open.
            logger.debug("Preflight VAD failed (\(error.localizedDescription, privacy: .public)) — proceeding to ASR")
            return .proceed
        }

        // Если VAD нашёл речь — сразу пропускаем (не тратим время на классификатор).
        if vadHasSpeech {
            return .proceed
        }

        // 2. Кросс-проверка SoundClassifier: коротим ASR только если он тоже уверен,
        //    что это тишина (а не шум/дыхание/неясная речь).
        let analysis = await audioAnalysis.classifySound(buffer)
        let confidentSilence = analysis.soundClass == .silence && analysis.confidence >= silenceConfidenceFloor

        if confidentSilence {
            logger.info(
                "Preflight: confident silence (VAD=no-speech, classifier=silence \(analysis.confidence, format: .fixed(precision: 2))) — skipping ASR"
            )
            return .likelySilent
        }
        return .proceed
    }

    // MARK: - Private

    /// Читает аудиофайл в 16kHz mono Float32 PCM-буфер (контракт VAD/классификатора).
    /// Возвращает `nil` при ошибке чтения/конвертации.
    static func loadMonoBuffer(url: URL, targetSampleRate: Double) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let sourceFormat = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount) else {
            return nil
        }
        do {
            try file.read(into: sourceBuffer)
        } catch {
            return nil
        }

        // Уже 16kHz mono — отдаём как есть.
        if sourceFormat.sampleRate == targetSampleRate && sourceFormat.channelCount == 1 {
            return sourceBuffer
        }

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ), let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            return nil
        }

        let ratio = targetSampleRate / sourceFormat.sampleRate
        let outCapacity = AVAudioFrameCount(Double(frameCount) * ratio) + 1
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCapacity) else {
            return nil
        }

        // `AVAudioConverter` зовёт input-блок синхронно на текущем потоке, но под
        // Swift 6 блок помечен `@Sendable`, поэтому состояние «отдан ли буфер»
        // держим в reference-боксе, а не в захваченной `var` (иначе data-race warning).
        let inputState = ConverterInputState(buffer: sourceBuffer)
        var convertError: NSError?
        let status = converter.convert(to: outBuffer, error: &convertError) { _, inputStatus in
            inputState.next(into: inputStatus)
        }
        guard status != .error, convertError == nil, outBuffer.frameLength > 0 else {
            return nil
        }
        return outBuffer
    }
}

// MARK: - ConverterInputState

/// Reference-бокс одноразовой выдачи входного буфера для `AVAudioConverter`.
///
/// `AVAudioConverter.convert(to:error:withInputFrom:)` вызывает input-блок
/// синхронно на текущем потоке, но под Swift 6 блок помечен `@Sendable`, поэтому
/// изменяемое состояние нельзя держать в захваченной `var` (data-race warning).
/// Класс отдаёт буфер ровно один раз, затем сообщает `.noDataNow`.
/// `@unchecked Sendable` обоснован: мутация происходит синхронно внутри
/// единственного вызова конвертера, без конкурентного доступа.
private final class ConverterInputState: @unchecked Sendable {
    private let buffer: AVAudioPCMBuffer
    private var consumed = false

    init(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func next(into status: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
        if consumed {
            status.pointee = .noDataNow
            return nil
        }
        consumed = true
        status.pointee = .haveData
        return buffer
    }
}

// MARK: - VADBox

/// Потокобезопасный ленивый кэш одного `VADProtocol`-инстанса. Первый вызов
/// поднимает реальный Silero v6 (FluidAudio) с graceful fallback на `AmplitudeVAD`;
/// последующие переиспользуют тот же детектор (модель не перегружается).
private actor VADBox {
    private var vad: (any VADProtocol)?

    func shared() async -> any VADProtocol {
        if let vad { return vad }
        let created = await makeVAD(preferFluidAudio: true)
        vad = created
        return created
    }
}

// MARK: - MockSpeechPreflightGate

/// Мок для тестов: всегда `.proceed` (как будто речь есть), либо настраиваемое решение.
public final class MockSpeechPreflightGate: SpeechPreflightGating, @unchecked Sendable {
    public var decision: SpeechPreflightDecision
    public init(decision: SpeechPreflightDecision = .proceed) {
        self.decision = decision
    }
    public func evaluate(url: URL) async -> SpeechPreflightDecision {
        decision
    }
}
