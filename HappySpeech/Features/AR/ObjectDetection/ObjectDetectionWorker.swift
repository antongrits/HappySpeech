import CoreImage
import OSLog
import Vision

// MARK: - ObjectDetectionWorkerProtocol

/// Протокол детектирования бытовых предметов в видеокадре.
/// Actor-изолирован — безопасен для вызова из любого Swift 6 контекста.
public protocol ObjectDetectionWorkerProtocol: Actor {
    /// Анализирует один `CVPixelBuffer` и возвращает объекты, совпадающие с `targetSound`.
    /// - Parameters:
    ///   - pixelBuffer: входной кадр (ARFrame.capturedImage или AVCaptureOutput).
    ///   - targetSound: строчный русский звук — фильтрует результаты (например "ш").
    ///                  Если `nil` — возвращает все распознанные объекты из маппинга.
    /// - Returns: массив `DetectedObject`, отсортированных по убыванию уверенности.
    func detect(in pixelBuffer: CVPixelBuffer, targetSound: String?) async throws -> [DetectedObject]
}

// MARK: - ObjectDetectionWorker

/// Real-time детектор бытовых предметов через `VNClassifyImageRequest` (Vision, iOS 17+).
///
/// Использует встроенный в Vision классификатор изображений (MobileNetV2-based, нет скачивания).
/// Маппинг ImageNet labels → русские слова + звуки загружается из `russian_object_mapping.json`.
///
/// Рабочий поток:
/// 1. `VNClassifyImageRequest` возвращает до 5 лучших классов с confidence > 0.3.
/// 2. Каждый класс ищется в словаре `mapping` (ключ = ImageNet label).
/// 3. Если задан `targetSound` — пропускаем объекты, у которых звук не входит в `sounds`.
/// 4. Возвращаем отфильтрованный список `DetectedObject`.
///
/// Производительность:
/// - `VNClassifyImageRequest` выполняется в ~30ms на A15+.
/// - Рекомендуемая частота вызова: 1 fps (из ARSession ticker).
///
/// Пример использования:
/// ```swift
/// let worker = try ObjectDetectionWorker()
/// let objects = try await worker.detect(in: frame.capturedImage, targetSound: "ш")
/// ```
public actor ObjectDetectionWorker: ObjectDetectionWorkerProtocol {

    // MARK: - Private

    private let request: VNClassifyImageRequest
    private let mapping: [String: ObjectMapping]
    private let logger = Logger(subsystem: "ru.happyspeech", category: "ObjectDetection")

    // MARK: - Constants

    private let confidenceThreshold: Float = 0.3
    private let maxResults: Int = 5

    // MARK: - Init

    /// - Throws: `ObjectDetectionError.mappingNotFound` если `russian_object_mapping.json`
    ///           отсутствует в бандле.
    public init() throws {
        guard let url = Bundle.main.url(forResource: "russian_object_mapping", withExtension: "json") else {
            throw ObjectDetectionError.mappingNotFound
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        self.mapping = try decoder.decode([String: ObjectMapping].self, from: data)

        let req = VNClassifyImageRequest()
        req.preferBackgroundProcessing = true
        self.request = req

        let logger = Logger(subsystem: "ru.happyspeech", category: "ObjectDetection")
        logger.info("ObjectDetectionWorker: initialized, mapping entries=\(self.mapping.count)")
    }

    // MARK: - Public API

    public func detect(in pixelBuffer: CVPixelBuffer, targetSound: String?) async throws -> [DetectedObject] {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([request])
        } catch {
            logger.error("ObjectDetectionWorker: VNImageRequestHandler.perform failed — \(error.localizedDescription)")
            throw ObjectDetectionError.visionRequestFailed(error.localizedDescription)
        }

        guard let observations = request.results else {
            logger.debug("ObjectDetectionWorker: no results from VNClassifyImageRequest")
            return []
        }

        // Нормализованный целевой звук для сравнения
        let normalizedTarget = targetSound?.lowercased()

        // Snapshot локальных значений для использования в замыкании (Swift 6 strict concurrency)
        let localMapping = self.mapping
        let localThreshold = self.confidenceThreshold

        let detected: [DetectedObject] = observations
            .prefix(maxResults)
            .compactMap { obs -> DetectedObject? in
                guard obs.confidence > localThreshold else { return nil }

                // Ищем точное совпадение с ImageNet label
                let entry: ObjectMapping
                if let exact = localMapping[obs.identifier] {
                    entry = exact
                } else {
                    // Частичное совпадение — некоторые ImageNet labels содержат суффиксы
                    let shortKey = obs.identifier.components(separatedBy: ",")
                        .first?.trimmingCharacters(in: .whitespaces) ?? obs.identifier
                    guard let shortEntry = localMapping[shortKey] else { return nil }
                    entry = shortEntry
                }

                // Фильтр по целевому звуку
                if let target = normalizedTarget {
                    let soundMatch = entry.sounds.contains { $0.lowercased() == target }
                    guard soundMatch else { return nil }
                }

                return DetectedObject(
                    imageNetLabel: obs.identifier,
                    russianLabel: entry.ru,
                    confidence: obs.confidence,
                    sounds: entry.sounds
                )
            }

        logger.debug("ObjectDetectionWorker: detected=\(detected.count) sound=\(normalizedTarget ?? "all")")
        return detected
    }
}

// MARK: - MockObjectDetectionWorker (Preview / Tests)

/// Mock-реализация для Preview и Unit-тестов.
/// Возвращает предсказуемый результат без использования Vision.
public actor MockObjectDetectionWorker: ObjectDetectionWorkerProtocol {

    private let mockObjects: [DetectedObject]

    public init() {
        self.mockObjects = [
            DetectedObject(
                imageNetLabel: "scarf",
                russianLabel: "шарф",
                confidence: 0.87,
                sounds: ["ш", "р", "ф"]
            ),
            DetectedObject(
                imageNetLabel: "hat",
                russianLabel: "шапка",
                confidence: 0.71,
                sounds: ["ш", "п", "к"]
            )
        ]
    }

    public func detect(in pixelBuffer: CVPixelBuffer, targetSound: String?) async throws -> [DetectedObject] {
        let target = targetSound?.lowercased()
        if let target {
            return mockObjects.filter { $0.sounds.contains(target) }
        }
        return mockObjects
    }
}
