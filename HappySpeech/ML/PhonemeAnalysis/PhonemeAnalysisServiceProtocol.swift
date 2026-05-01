import Foundation

// MARK: - PhonemeAnalysisService

/// Сервис фонемного анализа произношения.
///
/// Принимает сырой PCM аудио (Data, 16kHz mono Float32) и ожидаемое слово,
/// возвращает детальный анализ с оценкой по каждой фонеме.
///
/// **Детский контур:** ВСЕГДА на устройстве (CoreML Tier A).
/// **Архитектура:** MFCC → RussianPhonemeClassifier → DTW alignment → оценка.
///
/// ## Пример
/// ```swift
/// let result = try await phonemeAnalysisService.analyze(audio: pcmData, expectedWord: "школа")
/// let score = result.overallScore   // 0.87
/// let problems = result.problemPhonemes.map(\.ipa)  // ["ʂ"]
/// ```
///
/// ## See Also
/// - ``PhonemeAnalysisResult``
/// - ``G2PWorker``
/// - ``RussianPhonemeClassifierWrapper``
public protocol PhonemeAnalysisService: Actor {
    /// Анализирует произношение слова.
    /// - Parameters:
    ///   - audio: сырой PCM Data (Float32, 16kHz mono, ≥0.3–2.0 сек)
    ///   - expectedWord: ожидаемое слово на русском языке (нижний регистр)
    /// - Returns: детальный результат с оценкой по фонемам
    /// - Throws: ``PhonemeAnalysisError`` при ошибке модели или MFCC
    func analyze(audio: Data, expectedWord: String) async throws -> PhonemeAnalysisResult
}

// MARK: - MFCCExtractorProtocol

/// Протокол для MFCC-экстрактора — позволяет подменять в тестах.
///
/// Реальная реализация: `MFCCExtractorAdapter` (адаптер над `MFCCExtractor` enum).
/// Mock реализация: `MockMFCCExtractor` для unit-тестов.
public protocol MFCCExtractorProtocol: Sendable {
    /// Извлекает MFCC фреймы из PCM Data.
    /// - Parameter audio: Float32 PCM Data, 16kHz mono
    /// - Returns: массив фреймов [[Float]], каждый фрейм — 39 MFCC коэффициентов
    func extract(from audio: Data) async throws -> [[Float]]
}
