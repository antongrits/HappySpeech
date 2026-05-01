import Foundation

// MARK: - Phoneme

/// Ожидаемая фонема (из G2P словаря или правилового fallback).
public struct Phoneme: Sendable, Codable, Equatable, Hashable {
    /// IPA символ фонемы, например: "ʂ", "k", "o", "l", "a".
    public let ipa: String
    /// Позиция фонемы в слове (0-based).
    public let position: Int

    public init(ipa: String, position: Int) {
        self.ipa = ipa
        self.position = position
    }
}

// MARK: - PhonemeAlignment

/// Предсказанная фонема для конкретного фрейма.
public struct PhonemeAlignment: Sendable, Codable {
    /// Индекс временного фрейма (0..<150).
    public let frameIndex: Int
    /// IPA символ предсказанной фонемы.
    public let predictedIPA: String
    /// Уверенность модели (0.0–1.0, после softmax).
    public let confidence: Double

    public init(frameIndex: Int, predictedIPA: String, confidence: Double) {
        self.frameIndex = frameIndex
        self.predictedIPA = predictedIPA
        self.confidence = confidence
    }
}

// MARK: - PhonemeAnalysisResult

/// Результат фонемного анализа произношения.
public struct PhonemeAnalysisResult: Sendable, Codable {
    /// Ожидаемые фонемы (из G2P словаря).
    public let expectedPhonemes: [Phoneme]
    /// Предсказанные фонемы по фреймам (из CoreML модели).
    public let predictedPhonemes: [PhonemeAlignment]
    /// DTW alignment score (0.0–1.0), где 1.0 — идеальное совпадение.
    public let alignmentScore: Double
    /// Оценка по каждой ожидаемой фонеме: ["ʂ": 0.92, "k": 0.85].
    public let perPhonemeScore: [String: Double]
    /// Суммарный score (взвешенное среднее perPhonemeScore, 0.0–1.0).
    public let overallScore: Double
    /// Проблемные фонемы — те, чей score < 0.6.
    public let problemPhonemes: [Phoneme]

    public init(
        expectedPhonemes: [Phoneme],
        predictedPhonemes: [PhonemeAlignment],
        alignmentScore: Double,
        perPhonemeScore: [String: Double],
        overallScore: Double,
        problemPhonemes: [Phoneme]
    ) {
        self.expectedPhonemes = expectedPhonemes
        self.predictedPhonemes = predictedPhonemes
        self.alignmentScore = alignmentScore
        self.perPhonemeScore = perPhonemeScore
        self.overallScore = overallScore
        self.problemPhonemes = problemPhonemes
    }
}

// MARK: - Errors

/// Ошибки сервиса фонемного анализа.
public enum PhonemeAnalysisError: Error, LocalizedError, Sendable {
    case modelNotLoaded
    case mfccExtractionFailed
    case predictionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return String(localized: "Модель фонемного анализа не загружена")
        case .mfccExtractionFailed:
            return String(localized: "Ошибка извлечения MFCC признаков")
        case .predictionFailed(let detail):
            return String(localized: "Ошибка предсказания фонем: \(detail)")
        }
    }
}

/// Ошибки G2P словаря.
public enum G2PError: Error, LocalizedError, Sendable {
    case dictionaryNotFound
    case wordNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .dictionaryNotFound:
            return String(localized: "Словарь произношения не найден в бандле")
        case .wordNotFound(let word):
            return String(localized: "Слово '\(word)' не найдено в словаре")
        }
    }
}

// MARK: - RussianPhonemeInventory

/// Инвентарь 49 IPA фонем русского языка (соответствует russian_phonemes.json metadata).
///
/// Порядок классов совпадает с выходом модели `RussianPhonemeClassifier.mlpackage`:
/// Output: `phoneme_logits [1, 150, 49]` — индекс в массиве = индекс класса.
public enum RussianPhonemeInventory {
    public static let all: [String] = [
        // Согласные парные глухие/звонкие
        "b", "p", "d", "t", "g", "k", "v", "f", "z", "s", "ʐ", "ʂ",
        // Аффрикаты и фрикативные
        "ts", "tɕ", "ɕː", "x",
        // Сонорные
        "m", "n", "l", "r", "j",
        // Палатализованные согласные
        "bʲ", "pʲ", "dʲ", "tʲ", "gʲ", "kʲ", "vʲ", "fʲ", "zʲ", "sʲ",
        "mʲ", "nʲ", "lʲ", "rʲ", "xʲ",
        // Гласные
        "a", "e", "i", "o", "u", "ɨ", "æ", "ə", "ɪ", "ɔ", "ɛ", "ɵ", "ʌ"
    ]

    /// Возвращает IPA фонему по индексу класса модели.
    public static func phoneme(at index: Int) -> String? {
        guard index >= 0, index < all.count else { return nil }
        return all[index]
    }

    /// Возвращает индекс класса по IPA символу.
    public static func index(of ipa: String) -> Int? {
        all.firstIndex(of: ipa)
    }
}
