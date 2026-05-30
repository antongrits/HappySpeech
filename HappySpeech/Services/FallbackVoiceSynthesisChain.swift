import Foundation
import OSLog

// MARK: - FallbackVoiceSynthesisChain

/// Пробует список ``VoiceSynthesisMode`` по порядку до первого успешного синтеза.
///
/// Назначение — устойчивая озвучка: если семейная запись отсутствует, переходим к
/// системному TTS, затем к bundled-аудио. Каждая неудача логируется (OSLog) и не
/// прерывает цепочку; ошибка пробрасывается только если **все** режимы провалились.
///
/// ## Пример
/// ```swift
/// let chain = FallbackVoiceSynthesisChain(service: voiceCloneService)
/// let data = try await chain.synthesize(
///     text: "Слушай и повторяй",
///     modes: [
///         .familyVoice(audioFilePath: "family_recordings/mama-1.m4a"),
///         .systemTTS(locale: "ru-RU"),
///         .bundledAudio(resourceName: "fallback_listen_and_repeat")
///     ]
/// )
/// ```
public struct FallbackVoiceSynthesisChain: Sendable {

    private let service: any VoiceCloneService
    private let logger = Logger(subsystem: "ru.happyspeech.app", category: "VoiceClone.Fallback")

    public init(service: any VoiceCloneService) {
        self.service = service
    }

    /// Пытается синтезировать `text`, перебирая `modes` по порядку.
    /// Возвращает данные первого успешного режима.
    /// - Throws: ``VoiceCloneError/synthesisFailed`` если список пуст,
    ///   либо последнюю встреченную ошибку, если все режимы провалились.
    public func synthesize(text: String, modes: [VoiceSynthesisMode]) async throws -> Data {
        guard !modes.isEmpty else {
            logger.warning("Fallback chain called with empty modes list")
            throw VoiceCloneError.synthesisFailed
        }

        var lastError: Error?
        for (index, mode) in modes.enumerated() {
            do {
                let data = try await service.synthesize(text: text, mode: mode)
                guard !data.isEmpty else {
                    logger.warning("Fallback step \(index) produced empty data — trying next")
                    lastError = VoiceCloneError.synthesisFailed
                    continue
                }
                logger.info("Fallback chain succeeded at step \(index)/\(modes.count - 1)")
                return data
            } catch {
                logger.warning("Fallback step \(index) failed: \(error.localizedDescription, privacy: .public) — trying next")
                lastError = error
                continue
            }
        }

        logger.error("Fallback chain exhausted — all \(modes.count) modes failed")
        throw lastError ?? VoiceCloneError.synthesisFailed
    }
}
