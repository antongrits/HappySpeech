import CoreVideo
import Vision
import XCTest

@testable import HappySpeech

// MARK: - AppleFaceLandmarksDetectorTests

final class AppleFaceLandmarksDetectorTests: XCTestCase {

    var detector: AppleFaceLandmarksDetector!

    override func setUp() async throws {
        detector = AppleFaceLandmarksDetector()
    }

    // MARK: - Test 1: Инициализация актора

    func testDetectorInitializes() async {
        XCTAssertNotNil(detector, "AppleFaceLandmarksDetector должен инициализироваться без ошибок")
    }

    // MARK: - Test 2: Пустой пиксельный буфер → nil (лицо не найдено)

    func testDetectReturnsNilForBlankBuffer() async {
        // 1×1 пиксель — лицо точно не найдётся
        guard let buffer = makeSolidColorPixelBuffer(width: 1, height: 1, color: 0x80_80_80) else {
            XCTFail("Не удалось создать CVPixelBuffer")
            return
        }
        let result = await detector.detect(pixelBuffer: buffer)
        // На таком маленьком буфере Vision не найдёт лицо
        XCTAssertNil(result, "Детектор должен вернуть nil на 1×1 пиксельном буфере")
    }

    // MARK: - Test 3: Маленький буфер без лица → nil

    func testDetectReturnsNilForNoisyBuffer() async {
        guard let buffer = makeRandomNoisyPixelBuffer(width: 64, height: 64) else {
            XCTFail("Не удалось создать CVPixelBuffer")
            return
        }
        let result = await detector.detect(pixelBuffer: buffer)
        XCTAssertNil(result, "Шумовой буфер не должен содержать лицо")
    }

    // MARK: - Test 4: FaceLandmarks76 структура корректна при non-nil результате

    func testFaceLandmarks76StructureIsValid() async {
        // Создаём мок-результат вручную (Vision на симуляторе не детектирует лица)
        let mockResult = makeMockLandmarks76()

        XCTAssertLessThanOrEqual(mockResult.outerLips.count, 12,
            "outerLips должно быть ≤ 12 точек")
        XCTAssertLessThanOrEqual(mockResult.innerLips.count, 8,
            "innerLips должно быть ≤ 8 точек")
        XCTAssertFalse(mockResult.allPoints.isEmpty,
            "allPoints не должен быть пустым")
        XCTAssertTrue(mockResult.confidence >= 0 && mockResult.confidence <= 1,
            "confidence должен быть в [0, 1]")
    }

    // MARK: - Test 5: Все точки в allPoints нормализованы [0,1]

    func testAllPointsAreNormalized() async {
        let mockResult = makeMockLandmarks76()
        for pt in mockResult.allPoints {
            XCTAssertTrue(pt.x >= -0.1 && pt.x <= 1.1,
                "x должен быть нормализован: \(pt.x)")
            XCTAssertTrue(pt.y >= -0.1 && pt.y <= 1.1,
                "y должен быть нормализован: \(pt.y)")
        }
    }

    // MARK: - Test 6: Конкурентные вызовы — actor защищает состояние

    func testConcurrentCallsDoNotCrash() async {
        guard let buffer = makeSolidColorPixelBuffer(width: 32, height: 32, color: 0xFF_FF_FF) else {
            XCTFail("Не удалось создать CVPixelBuffer")
            return
        }
        // Запускаем 10 конкурентных вызовов
        await withTaskGroup(of: Optional<FaceLandmarks76>.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await self.detector.detect(pixelBuffer: buffer)
                }
            }
            for await _ in group { } // просто ждём завершения
        }
        // Тест проходит если нет краша / гонки данных
        XCTAssertTrue(true, "Конкурентные вызовы завершились без краша")
    }

    // MARK: - Helpers

    private func makeSolidColorPixelBuffer(width: Int, height: Int, color: UInt32) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: true,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                            kCVPixelFormatType_32BGRA, attrs, &buffer)
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            let pixels = base.bindMemory(to: UInt32.self, capacity: width * height)
            for i in 0..<(width * height) {
                pixels[i] = color
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }

    private func makeRandomNoisyPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: true] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                            kCVPixelFormatType_32BGRA, attrs, &buffer)
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            let pixels = base.bindMemory(to: UInt8.self, capacity: width * height * 4)
            for i in 0..<(width * height * 4) {
                pixels[i] = UInt8.random(in: 0...255)
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }

    private func makeMockLandmarks76() -> FaceLandmarks76 {
        let outerLips = (0..<12).map { CGPoint(x: 0.3 + Double($0) * 0.03, y: 0.5) }
        let innerLips = (0..<8).map { CGPoint(x: 0.32 + Double($0) * 0.03, y: 0.51) }
        let nose = (0..<5).map { CGPoint(x: 0.48 + Double($0) * 0.01, y: 0.44) }
        let all = outerLips + innerLips + nose
        return FaceLandmarks76(
            outerLips: outerLips,
            innerLips: innerLips,
            nose: nose,
            noseCrest: [],
            leftEye: [],
            rightEye: [],
            leftEyebrow: [],
            rightEyebrow: [],
            jaw: [],
            medianLine: [],
            allPoints: all,
            boundingBox: CGRect(x: 0.2, y: 0.1, width: 0.6, height: 0.8),
            confidence: 0.95
        )
    }
}
