@testable import HappySpeech
import CoreVideo
import XCTest

// MARK: - ObjectDetectionWorkerTests
//
// Покрывает:
//   - доменные модели DetectedObject / ObjectMapping;
//   - ошибки ObjectDetectionError (локализованные сообщения);
//   - фильтрацию по целевому звуку в MockObjectDetectionWorker (та же
//     контрактная логика, что в live worker: targetSound==nil → все,
//     иначе только объекты, содержащие звук);
//   - live worker (если ресурс маппинга доступен в тест-бандле) — graceful
//     поведение на пустом кадре.
//
// ПОКРЫТО НЕ ВСЁ: приватная компоновка DetectedObject из VNClassifyImageRequest
// в live worker зависит от встроенного Vision-классификатора и реального кадра
// с предметом; VNClassificationObservation нельзя инстанцировать вручную.
// Поэтому маппинг ImageNet→русское слово проверяется на уровне контракта
// (фильтрация по звуку) через Mock, а Vision-распознавание — device-тест.

final class ObjectDetectionWorkerTests: XCTestCase {

    // MARK: - DetectedObject model

    func test_detectedObject_storesAllFields() {
        let obj = DetectedObject(imageNetLabel: "umbrella", russianLabel: "зонт",
                                 confidence: 0.82, sounds: ["з", "т"])
        XCTAssertEqual(obj.imageNetLabel, "umbrella")
        XCTAssertEqual(obj.russianLabel, "зонт")
        XCTAssertEqual(obj.confidence, 0.82, accuracy: 0.0001)
        XCTAssertEqual(obj.sounds, ["з", "т"])
    }

    // MARK: - ObjectMapping decoding

    func test_objectMapping_decodesFromJSON() throws {
        let json = #"{"ru":"шарф","sounds":["ш","р","ф"]}"#.data(using: .utf8)!
        let mapping = try JSONDecoder().decode(ObjectMapping.self, from: json)
        XCTAssertEqual(mapping.ru, "шарф")
        XCTAssertEqual(mapping.sounds, ["ш", "р", "ф"])
    }

    func test_objectMappingDictionary_decodes() throws {
        let json = #"{"umbrella":{"ru":"зонт","sounds":["з"]},"scarf":{"ru":"шарф","sounds":["ш"]}}"#
            .data(using: .utf8)!
        let dict = try JSONDecoder().decode([String: ObjectMapping].self, from: json)
        XCTAssertEqual(dict.count, 2)
        XCTAssertEqual(dict["umbrella"]?.ru, "зонт")
        XCTAssertEqual(dict["scarf"]?.sounds, ["ш"])
    }

    // MARK: - ObjectDetectionError

    func test_error_descriptions_nonEmpty() {
        XCTAssertFalse(ObjectDetectionError.mappingNotFound.errorDescription?.isEmpty ?? true)
        let visionErr = ObjectDetectionError.visionRequestFailed("timeout")
        XCTAssertNotNil(visionErr.errorDescription)
        XCTAssertTrue(visionErr.errorDescription?.contains("timeout") ?? false,
                      "Сообщение содержит причину")
    }

    // MARK: - MockObjectDetectionWorker: filtering contract

    func test_mock_targetSoundNil_returnsAll() async throws {
        let result = try await Self.runMockDetect(targetSound: nil)
        XCTAssertEqual(result.count, 2, "Без фильтра — все объекты мока")
    }

    func test_mock_targetSoundSh_returnsBothSibilants() async throws {
        // Оба мок-объекта (шарф, шапка) содержат звук "ш".
        let result = try await Self.runMockDetect(targetSound: "ш")
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.sounds.contains("ш") })
    }

    func test_mock_targetSoundUnique_returnsSubset() async throws {
        // Звук "ф" есть только у шарфа.
        let result = try await Self.runMockDetect(targetSound: "ф")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.russianLabel, "шарф")
    }

    func test_mock_targetSoundAbsent_returnsEmpty() async throws {
        // Звука "ы" нет ни у одного мок-объекта.
        let result = try await Self.runMockDetect(targetSound: "ы")
        XCTAssertTrue(result.isEmpty)
    }

    func test_mock_caseInsensitiveSound() async throws {
        // targetSound нормализуется к нижнему регистру в реализации мока.
        let result = try await Self.runMockDetect(targetSound: "Ш")
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - Live worker: graceful (resource-dependent)

    func test_live_blankFrame_returnsEmptyOrThrowsMappingNotFound() async throws {
        // Маппинг лежит в Resources приложения (Bundle.main приложения).
        // Под тестовым хостом ресурс может быть недоступен — тогда init бросает
        // mappingNotFound. Оба исхода допустимы; ключевое — нет краша.
        let worker: ObjectDetectionWorker
        do {
            worker = try ObjectDetectionWorker()
        } catch ObjectDetectionError.mappingNotFound {
            // Ресурс не в тест-бандле — корректная graceful-ошибка init.
            return
        }
        // Buffer создаётся и потребляется внутри одного nonisolated-региона
        // (Self.runLiveDetect) — CVPixelBuffer не Sendable, наружу не «утекает».
        //
        // На симуляторе/CI Vision Neural Engine context может быть недоступен
        // («espresso context») — тогда worker бросает visionRequestFailed.
        // Это валидный graceful-исход (worker оборачивает ошибку Vision, не
        // падает); принимаем его наравне с пустым результатом.
        do {
            let result = try await Self.runLiveDetect(worker, targetSound: "ш")
            XCTAssertTrue(result.isEmpty, "Пустой кадр → нет распознанных объектов")
        } catch ObjectDetectionError.visionRequestFailed {
            // Vision-контекст недоступен в тест-хосте — корректная обёртка ошибки.
        }
    }

    // MARK: - Detect helpers (Sendable-safe buffer handling)
    //
    // Buffer создаётся локально внутри helper и сразу передаётся актору; наружу
    // возвращается только Sendable-результат [DetectedObject]. Это держит
    // не-Sendable CVPixelBuffer в одном регионе (Swift 6 region isolation).

    private static func runMockDetect(targetSound: String?) async throws -> [DetectedObject] {
        let sut = MockObjectDetectionWorker()
        let buffer = try XCTUnwrap(makePixelBuffer())
        return try await sut.detect(in: buffer, targetSound: targetSound)
    }

    private static func runLiveDetect(
        _ worker: ObjectDetectionWorker,
        targetSound: String?
    ) async throws -> [DetectedObject] {
        let buffer = try XCTUnwrap(makePixelBuffer())
        return try await worker.detect(in: buffer, targetSound: targetSound)
    }

    // MARK: - Pixel buffer helper

    private static func makePixelBuffer(width: Int = 64, height: Int = 64) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                            kCVPixelFormatType_32BGRA, attrs, &buffer)
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            memset(base, 110, CVPixelBufferGetBytesPerRow(buffer) * height)
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
}
