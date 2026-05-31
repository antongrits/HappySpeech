@testable import HappySpeech
import AVFoundation
import CoreVideo
import XCTest

// MARK: - FaceAnalysisServiceTests
//
// Покрывает чистую логику LiveFaceAnalysisService:
//   - analyzeLipSymmetry (vDSP min/max + геометрия центра рта);
//   - detectAirStream (vDSP RMS + нормализация дыхательного диапазона);
//   - graceful-ветки на пустых/недостаточных входах;
//   - analyzeFaceLandmarks на пустом кадре (нет лица → nil).
// MockFaceAnalysisService — фиксированный контракт.

final class FaceAnalysisServiceTests: XCTestCase {

    private static let sampleRate: Double = 16_000

    private static func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: sampleRate, channels: 1, interleaved: false)!
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(max(samples.count, 1)))!
        buf.frameLength = AVAudioFrameCount(samples.count)
        for (i, s) in samples.enumerated() { buf.floatChannelData![0][i] = s }
        return buf
    }

    private static func tone(_ n: Int, amp: Float, freq: Float = 220) -> [Float] {
        (0 ..< n).map { amp * sin(2 * .pi * freq * Float($0) / Float(sampleRate)) }
    }

    /// Конструирует FaceLandmarkResult напрямую (mouthPoints — единственное, что
    /// нужно для analyzeLipSymmetry; landmark-детектор отдельно).
    private func landmarks(mouthPoints: [CGPoint]) -> FaceLandmarkResult {
        FaceLandmarkResult(
            allPoints: mouthPoints,
            mouthPoints: mouthPoints,
            leftEyePoints: [],
            rightEyePoints: [],
            jawPoints: [],
            boundingBox: CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4),
            confidence: 0.9
        )
    }

    // MARK: - analyzeLipSymmetry: insufficient points (edge case)

    func test_lipSymmetry_tooFewPoints_returnsNeutralDefault() {
        let sut = LiveFaceAnalysisService()
        let result = sut.analyzeLipSymmetry(landmarks: landmarks(mouthPoints: [
            CGPoint(x: 0.4, y: 0.5), CGPoint(x: 0.6, y: 0.5)
        ]))
        XCTAssertEqual(result.symmetryScore, 0.5, accuracy: 0.001)
        XCTAssertFalse(result.isOpen)
        XCTAssertEqual(result.mouthOpenRatio, 0, accuracy: 0.001)
    }

    // MARK: - analyzeLipSymmetry: centered mouth → high symmetry (happy path)

    func test_lipSymmetry_centeredMouth_highSymmetry() {
        let sut = LiveFaceAnalysisService()
        // Рот симметричен относительно центра кадра (0.5).
        let pts = [
            CGPoint(x: 0.35, y: 0.50),
            CGPoint(x: 0.65, y: 0.50),
            CGPoint(x: 0.50, y: 0.45),
            CGPoint(x: 0.50, y: 0.55)
        ]
        let result = sut.analyzeLipSymmetry(landmarks: landmarks(mouthPoints: pts))
        XCTAssertGreaterThan(result.symmetryScore, 0.9, "Центрированный рот → высокая симметрия")
        XCTAssertEqual(result.leftCorner.x, 0.35, accuracy: 0.001)
        XCTAssertEqual(result.rightCorner.x, 0.65, accuracy: 0.001)
    }

    // MARK: - analyzeLipSymmetry: offset mouth → low symmetry

    func test_lipSymmetry_offsetMouth_lowSymmetry() {
        let sut = LiveFaceAnalysisService()
        // Рот сильно смещён вправо от центра кадра.
        let pts = [
            CGPoint(x: 0.70, y: 0.50),
            CGPoint(x: 0.95, y: 0.50),
            CGPoint(x: 0.80, y: 0.48),
            CGPoint(x: 0.82, y: 0.52)
        ]
        let result = sut.analyzeLipSymmetry(landmarks: landmarks(mouthPoints: pts))
        XCTAssertLessThan(result.symmetryScore, 0.5, "Смещённый рот → низкая симметрия")
        XCTAssertTrue((0.0...1.0).contains(result.symmetryScore), "Симметрия клампится в [0,1]")
    }

    // MARK: - analyzeLipSymmetry: open mouth detection

    func test_lipSymmetry_openMouth_isOpenTrue() {
        let sut = LiveFaceAnalysisService()
        // Высота заметно больше ширины * 0.15 → рот открыт.
        let pts = [
            CGPoint(x: 0.45, y: 0.40),
            CGPoint(x: 0.55, y: 0.40),
            CGPoint(x: 0.50, y: 0.30),
            CGPoint(x: 0.50, y: 0.60)
        ]
        let result = sut.analyzeLipSymmetry(landmarks: landmarks(mouthPoints: pts))
        XCTAssertTrue(result.isOpen, "Высокий mouthOpenRatio → рот открыт")
        XCTAssertGreaterThan(result.mouthOpenRatio, 0.15)
    }

    // MARK: - detectAirStream: happy path

    func test_detectAirStream_breathingLevel_isBreathingTrue() async {
        let sut = LiveFaceAnalysisService()
        // RMS в дыхательном диапазоне (нормализованный 0.05..0.7).
        let result = await sut.detectAirStream(buffer: Self.makeBuffer(Self.tone(512, amp: 0.05)))
        XCTAssertTrue(result.isBreathing, "Тон дыхательного уровня → isBreathing")
        XCTAssertGreaterThan(result.confidence, 0)
        XCTAssertTrue((0.0...1.0).contains(result.rmsLevel))
    }

    func test_detectAirStream_silence_notBreathing() async {
        let sut = LiveFaceAnalysisService()
        let result = await sut.detectAirStream(buffer: Self.makeBuffer([Float](repeating: 0, count: 512)))
        XCTAssertFalse(result.isBreathing, "Тишина → не дыхание")
        XCTAssertEqual(result.confidence, 0, accuracy: 0.001)
    }

    func test_detectAirStream_screaming_notBreathing() async {
        let sut = LiveFaceAnalysisService()
        // Очень громкий сигнал → normalized > 0.7 → крик, не дыхание.
        let result = await sut.detectAirStream(buffer: Self.makeBuffer(Self.tone(512, amp: 0.95)))
        XCTAssertFalse(result.isBreathing, "Крик/шум (> 0.7) → не дыхание")
    }

    func test_detectAirStream_emptyBuffer_returnsZero() async {
        let sut = LiveFaceAnalysisService()
        let result = await sut.detectAirStream(buffer: Self.makeBuffer([]))
        XCTAssertEqual(result.rmsLevel, 0, accuracy: 0.001)
        XCTAssertFalse(result.isBreathing)
    }

    // MARK: - analyzeFaceLandmarks: blank frame → nil

    func test_analyzeFaceLandmarks_blankFrame_returnsNil() async {
        let sut = LiveFaceAnalysisService()
        guard let pixelBuffer = Self.makeSolidPixelBuffer(width: 64, height: 64) else {
            return XCTFail("Не удалось создать pixel buffer")
        }
        // Пустой серый кадр без лица → детектор не находит лицо → nil.
        let result = await sut.analyzeFaceLandmarks(pixelBuffer: pixelBuffer)
        XCTAssertNil(result, "На кадре без лица landmarks == nil")
    }

    // MARK: - MockFaceAnalysisService contract

    func test_mock_returnsStubbedValues() async throws {
        let mock = MockFaceAnalysisService()
        let buffer = try XCTUnwrap(Self.makeSolidPixelBuffer(width: 8, height: 8))
        // analyzeFaceLandmarks возвращает заданный mockLandmarkResult.
        let initial = await mock.analyzeFaceLandmarks(pixelBuffer: buffer)
        XCTAssertNil(initial)
        mock.mockLandmarkResult = landmarks(mouthPoints: [CGPoint(x: 0.5, y: 0.5)])
        let landmark = await mock.analyzeFaceLandmarks(pixelBuffer: buffer)
        XCTAssertNotNil(landmark)

        let sym = mock.analyzeLipSymmetry(landmarks: landmark!)
        XCTAssertEqual(sym.symmetryScore, 0.85, accuracy: 0.001)
        XCTAssertTrue(sym.isOpen)

        let air = await mock.detectAirStream(buffer: Self.makeBuffer(Self.tone(64, amp: 0.3)))
        XCTAssertTrue(air.isBreathing)
        XCTAssertEqual(air.rmsLevel, 0.3, accuracy: 0.001)
    }

    // MARK: - Pixel buffer helper

    private static func makeSolidPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
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
            let bytes = CVPixelBufferGetBytesPerRow(buffer) * height
            memset(base, 128, bytes)
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
}
