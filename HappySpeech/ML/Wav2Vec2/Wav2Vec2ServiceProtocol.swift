import Foundation

// MARK: - Wav2Vec2Service

/// Сервис Tier 3 фонемного анализа через Wav2Vec2 CTC.
///
/// Принимает сырое PCM аудио (Data, Float32, 16 kHz mono, 3 сек / 48 000 сэмплов)
/// и возвращает последовательность фонемных logit'ов после CTC greedy декодирования.
///
/// ## Архитектура трёх уровней:
///
/// - **Tier 1:** `PronunciationScorerService` — MFCC CNN, <50 ms, поверхностные признаки.
/// - **Tier 2:** `RussianPhonemeClassifier` — CNN фонемный классификатор, ~100 ms.
/// - **Tier 3:** `Wav2Vec2Service` — CTC трансформер, 200–500 ms, глубокий анализ.
///
/// Tier 3 вызывается только при низкой уверенности Tier 1/2 (confidence < 0.70).
///
/// ## Пример
/// ```swift
/// let result = try await wav2Vec2Service.transcribe(audio: pcmData)
/// let text = result.decodedText        // "кот"
/// let conf = result.averageConfidence  // 0.82
/// ```
///
/// ## See Also
/// - ``CTCDecodeResult``
/// - ``PhonemeLogit``
/// - ``CTCDecoder``
public protocol Wav2Vec2Service: Actor {
    /// Транскрибирует 3-секундный PCM буфер (48 000 Float32 сэмплов @ 16 kHz).
    ///
    /// - Parameter audio: Data c сырыми Float32 сэмплами. Длина должна быть
    ///   от 8 000 до 80 000 сэмплов (0.5–5 сек @ 16 kHz).
    ///   Если короче 48 000 — паддится нулями до 48 000.
    ///   Если длиннее 48 000 — обрезается до 48 000.
    /// - Returns: CTC-декодированный результат с фонемами и текстом.
    /// - Throws: ``Wav2Vec2Error`` при ошибке модели или аудио.
    func transcribe(audio: Data) async throws -> CTCDecodeResult
}
