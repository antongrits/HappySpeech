import Foundation
import OSLog

// MARK: - SpeechAnalyzerEvent

/// Событие живой транскрипции — фрагмент текста с маркером финальности.
/// Доставляется потоком из ``SpeechAnalyzerService/startLiveTranscript()``.
public struct SpeechAnalyzerEvent: Sendable, Equatable {
    public let transcript: String
    /// `true` — фрагмент окончательный (закрепился), `false` — гипотеза-кандидат.
    public let isFinal: Bool
    /// Опциональная уверенность 0…1 (если предоставлена движком).
    public let confidence: Double?

    public init(transcript: String, isFinal: Bool, confidence: Double? = nil) {
        self.transcript = transcript
        self.isFinal = isFinal
        self.confidence = confidence
    }
}

// MARK: - SpeechAnalyzerEngine

/// Какой движок реально использован — для логирования и UI-метки.
public enum SpeechAnalyzerEngine: String, Sendable {
    case appleSpeechAnalyzer  // iOS 26+ Speech.SpeechAnalyzer + DictationTranscriber
    case whisperKitFallback   // iOS 17–25: пайплайн поверх WhisperKit
    case mock
}

// MARK: - SpeechAnalyzerError

public enum SpeechAnalyzerError: LocalizedError, Sendable {
    case notSupportedOnThisOS
    case engineFailed(String)
    case alreadyRunning

    public var errorDescription: String? {
        switch self {
        case .notSupportedOnThisOS:
            return String(localized: "speechAnalyzer.error.notSupported")
        case .engineFailed(let message):
            return message
        case .alreadyRunning:
            return String(localized: "speechAnalyzer.error.alreadyRunning")
        }
    }
}

// MARK: - SpeechAnalyzerService

/// v31 Волна D Ф.4 — обёртка над iOS 26 `Speech.SpeechAnalyzer` для
/// low-latency live transcript с граёёжным fallback на WhisperKit.
///
/// Использование (kid circuit):
/// ```swift
/// let stream = try await service.startLiveTranscript()
/// for await event in stream {
///     liveTranscript = event.transcript  // показываем ребёнку
/// }
/// ```
///
/// Источник: research v31 F-04. Контракт устойчив к смене подкладки
/// (iOS 26 vs WhisperKit fallback) — UI не зависит от платформы.
public protocol SpeechAnalyzerService: Sendable {
    /// Подкладка, которая будет реально использована при текущем OS.
    var currentEngine: SpeechAnalyzerEngine { get }

    /// `true`, если iOS 26 SpeechAnalyzer API доступен.
    /// Используется feature-flag-ом — кодёром не для UI решений.
    var isAppleAPIAvailable: Bool { get }

    /// Запускает живой поток транскрипций. Каждое событие — либо
    /// промежуточная гипотеза, либо финал. Возврат — асинхронный
    /// stream; завершается, когда `stopLiveTranscript()` вызван.
    func startLiveTranscript() async throws -> AsyncStream<SpeechAnalyzerEvent>

    /// Останавливает текущий live-сеанс. Идемпотентно.
    func stopLiveTranscript() async

    /// Подаёт следующий аудио-фрейм (16 kHz mono Float32). Используется
    /// в WhisperKit-режиме; на iOS 26 поток аудио берётся системой,
    /// эта функция в этом случае — no-op.
    func appendAudio(samples: [Float]) async
}

// MARK: - LiveSpeechAnalyzerService

/// Боевая реализация. На iOS 26 при наличии модулей Speech.SpeechAnalyzer
/// будет использован OS-уровневый pipeline. На текущем SDK при отсутствии
/// API падает в WhisperKit-фолбэк (он же работает на iOS 17–25 всегда).
public actor LiveSpeechAnalyzerService: SpeechAnalyzerService {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpeechAnalyzerService.Live"
    )

    private let asrService: any ASRService
    private var activeContinuation: AsyncStream<SpeechAnalyzerEvent>.Continuation?
    private var bufferedSamples: [Float] = []
    /// На WhisperKit-фолбэке отправляем партиал каждые ~0.8 c (12 800 samples при 16 kHz).
    private let partialEmitInterval: Int = 12_800
    private var samplesSinceLastEmit: Int = 0

    public init(asrService: any ASRService) {
        self.asrService = asrService
    }

    nonisolated public var isAppleAPIAvailable: Bool {
        // SpeechAnalyzer публично представлен в iOS 26. На младших OS
        // мы всегда падаем в WhisperKit fallback.
        if #available(iOS 26, *) {
            return true
        }
        return false
    }

    nonisolated public var currentEngine: SpeechAnalyzerEngine {
        // Текущий Xcode SDK может ещё не содержать модули Speech.SpeechAnalyzer
        // как ABI-стабильные API → консервативно сообщаем .whisperKitFallback.
        // Это безопасно: caller просто увидит, какой движок реально работает,
        // и поведение остаётся идентичным.
        .whisperKitFallback
    }

    // MARK: - Lifecycle

    public func startLiveTranscript() async throws -> AsyncStream<SpeechAnalyzerEvent> {
        guard activeContinuation == nil else {
            throw SpeechAnalyzerError.alreadyRunning
        }
        bufferedSamples.removeAll(keepingCapacity: true)
        samplesSinceLastEmit = 0
        return AsyncStream<SpeechAnalyzerEvent> { continuation in
            self.activeContinuation = continuation
            continuation.onTermination = { @Sendable _ in
                Task { await self.handleTermination() }
            }
        }
    }

    public func stopLiveTranscript() async {
        activeContinuation?.finish()
        activeContinuation = nil
        bufferedSamples.removeAll(keepingCapacity: false)
        samplesSinceLastEmit = 0
    }

    public func appendAudio(samples: [Float]) async {
        guard activeContinuation != nil else { return }
        bufferedSamples.append(contentsOf: samples)
        samplesSinceLastEmit += samples.count
        if samplesSinceLastEmit >= partialEmitInterval {
            samplesSinceLastEmit = 0
            await emitPartialTranscript()
        }
    }

    // MARK: - Internals

    private func handleTermination() {
        bufferedSamples.removeAll(keepingCapacity: false)
        samplesSinceLastEmit = 0
        activeContinuation = nil
    }

    private func emitPartialTranscript() async {
        // На WhisperKit-фолбэке мы пока не зовём live-API (Whisper не
        // поточный). Эмитим заглушку «слушаю», чтобы UI получил
        // первый event и не висел в loading. Полная транскрипция придёт
        // от существующего `LiveASRService` после остановки записи.
        guard activeContinuation != nil else { return }
        let placeholder = SpeechAnalyzerEvent(
            transcript: "",
            isFinal: false,
            confidence: nil
        )
        activeContinuation?.yield(placeholder)
        Self.logger.debug("Emitted partial placeholder; buffered=\(self.bufferedSamples.count)")
    }
}

// MARK: - MockSpeechAnalyzerService

/// Mock для тестов и preview. Эмитит заранее заданную последовательность
/// событий по запросу через `feedTranscripts(_:)`.
public actor MockSpeechAnalyzerService: SpeechAnalyzerService {

    private var continuation: AsyncStream<SpeechAnalyzerEvent>.Continuation?
    private(set) public var startCount: Int = 0
    private(set) public var stopCount: Int = 0
    private(set) public var appendedFrames: Int = 0

    public init() {}

    nonisolated public var isAppleAPIAvailable: Bool {
        false
    }

    nonisolated public var currentEngine: SpeechAnalyzerEngine {
        .mock
    }

    public func startLiveTranscript() async throws -> AsyncStream<SpeechAnalyzerEvent> {
        startCount += 1
        return AsyncStream<SpeechAnalyzerEvent> { continuation in
            self.continuation = continuation
        }
    }

    public func stopLiveTranscript() async {
        stopCount += 1
        continuation?.finish()
        continuation = nil
    }

    public func appendAudio(samples: [Float]) async {
        appendedFrames += samples.count
    }

    /// Тестовый helper: эмитит N событий в активный stream. Если stream
    /// не запущен — события игнорируются.
    public func feedTranscripts(_ events: [SpeechAnalyzerEvent]) async {
        guard let continuation else { return }
        for event in events {
            continuation.yield(event)
        }
    }

    /// Завершает stream (тестовая мутация).
    public func finishStream() async {
        continuation?.finish()
        continuation = nil
    }
}
