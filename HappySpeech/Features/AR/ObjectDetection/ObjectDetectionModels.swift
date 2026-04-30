import Foundation

// MARK: - ObjectMapping

/// Entry in `russian_object_mapping.json` — один объект ImageNet → русское слово.
struct ObjectMapping: Codable, Sendable {
    /// Русское название предмета. Пример: "зонт".
    let ru: String
    /// Список ключевых звуков в русском слове (строчные). Пример: ["з", "т"].
    let sounds: [String]
}

// MARK: - DetectedObject

/// Результат детектирования одного объекта на кадре.
public struct DetectedObject: Sendable {
    /// ImageNet-метка на английском. Пример: "umbrella".
    public let imageNetLabel: String
    /// Русское название. Пример: "зонт".
    public let russianLabel: String
    /// Уверенность Vision (0.0…1.0).
    public let confidence: Float
    /// Список ключевых звуков русского слова (строчные). Пример: ["з", "т"].
    public let sounds: [String]
}

// MARK: - ObjectDetectionError

/// Ошибки, которые может выбросить ObjectDetectionWorker.
enum ObjectDetectionError: LocalizedError, Sendable {
    case mappingNotFound
    case visionRequestFailed(String)

    var errorDescription: String? {
        switch self {
        case .mappingNotFound:
            return String(localized: "Файл маппинга объектов не найден")
        case .visionRequestFailed(let reason):
            return String(localized: "Ошибка распознавания: \(reason)")
        }
    }
}
