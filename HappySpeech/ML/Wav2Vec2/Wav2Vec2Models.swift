import Foundation

// MARK: - PhonemeLogit

/// Фонема с уверенностью для одного временного шага CTC-декодирования.
///
/// Используется в Tier 3 фонемного анализа (``Wav2Vec2ServiceLive``).
public struct PhonemeLogit: Sendable, Codable, Equatable {
    /// Индекс временного шага в CTC-выходе (0..<T, где T зависит от длины аудио).
    public let timestep: Int
    /// Индекс фонемы в словаре Wav2Vec2 (0..<37 для bond005/wav2vec2-large-ru-golos).
    public let phonemeIndex: Int
    /// Уверенность модели (softmax, 0.0–1.0).
    public let confidence: Double

    public init(timestep: Int, phonemeIndex: Int, confidence: Double) {
        self.timestep = timestep
        self.phonemeIndex = phonemeIndex
        self.confidence = confidence
    }
}

// MARK: - Wav2Vec2Error

/// Ошибки Wav2Vec2 CTC сервиса.
public enum Wav2Vec2Error: LocalizedError, Sendable {
    case modelNotLoaded
    case audioConversionFailed
    case audioTooShort(Int)
    case predictionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return String(localized: "Модель Wav2Vec2 не загружена")
        case .audioConversionFailed:
            return String(localized: "Ошибка конвертации аудио для Wav2Vec2")
        case .audioTooShort(let samples):
            return String(localized: "Аудио слишком короткое: \(samples) сэмплов (минимум 8000)")
        case .predictionFailed(let detail):
            return String(localized: "Ошибка инференса Wav2Vec2: \(detail)")
        }
    }
}

// MARK: - Wav2Vec2Vocabulary

/// Словарь 37 символов модели ``bond005/wav2vec2-large-ru-golos``.
///
/// Индекс соответствует выходу CTC головы модели.
/// Символ "|" — пробел (word boundary), "<pad>" — CTC blank token.
public enum Wav2Vec2Vocabulary {
    /// Упорядоченный список символов (индекс = позиция в CTC vocab).
    public static let symbols: [String] = [
        "<pad>", "<s>", "</s>", "<unk>", "|",
        "а", "б", "в", "г", "д", "е", "ж", "з", "и", "й",
        "к", "л", "м", "н", "о", "п", "р", "с", "т", "у",
        "ф", "х", "ц", "ч", "ш", "щ", "ъ", "ы", "ь", "э",
        "ю", "я"
    ]

    /// CTC blank token индекс.
    public static let blankIndex: Int = 0

    /// Индекс пробела / word boundary.
    public static let wordBoundaryIndex: Int = 4

    /// Возвращает символ по индексу.
    public static func symbol(at index: Int) -> String? {
        guard index >= 0, index < symbols.count else { return nil }
        return symbols[index]
    }

    /// Возвращает индекс по символу.
    public static func index(of symbol: String) -> Int? {
        symbols.firstIndex(of: symbol)
    }

    /// Размер словаря.
    public static var size: Int { symbols.count }
}

// MARK: - CTCDecodeResult

/// Результат CTC-декодирования.
public struct CTCDecodeResult: Sendable, Codable, Equatable {
    /// Последовательность фонемных logit'ов (топ-1 по каждому timestep после greedy collapse).
    public let phonemes: [PhonemeLogit]
    /// Декодированный текст (кириллица + пробелы).
    public let decodedText: String
    /// Средняя уверенность модели по всем timestep'ам.
    public let averageConfidence: Double

    public init(phonemes: [PhonemeLogit], decodedText: String, averageConfidence: Double) {
        self.phonemes = phonemes
        self.decodedText = decodedText
        self.averageConfidence = averageConfidence
    }
}
