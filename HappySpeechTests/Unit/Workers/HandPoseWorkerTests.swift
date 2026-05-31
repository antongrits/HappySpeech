@testable import HappySpeech
import CoreGraphics
import CoreVideo
import XCTest

// MARK: - HandPoseWorkerTests
//
// Покрывает:
//   - доменные модели HandPose / HandChirality / HandPoseObservation.empty;
//   - graceful-поведение live HandPoseWorker на пустом кадре (рука не найдена → nil).
//
// ПОКРЫТО НЕ ВСЁ: приватная эвристика classifyPose работает над
// VNRecognizedPoint из реального Vision-детектора. VNRecognizedPoint нельзя
// инстанцировать вручную (нет публичного init), а синтетический кадр не даёт
// детерминированной руки. Поэтому распознавание конкретных поз (pinch/fist/...)
// требует device/ресурсного теста и вынесено из unit-покрытия; здесь проверяем
// контракт (нет краша, корректный nil на отсутствии руки) и модели.

final class HandPoseWorkerTests: XCTestCase {

    // MARK: - HandPose model

    func test_handPose_allCases_haveDebugDescription() {
        for pose in HandPose.allCases {
            XCTAssertFalse(pose.debugDescription.isEmpty, "\(pose) должна иметь описание")
        }
    }

    func test_handPose_rawValues_stable() {
        XCTAssertEqual(HandPose.openPalm.rawValue, "open_palm")
        XCTAssertEqual(HandPose.thumbsUp.rawValue, "thumbs_up")
        XCTAssertEqual(HandPose(rawValue: "fist"), .fist)
        XCTAssertNil(HandPose(rawValue: "nope"))
    }

    // MARK: - HandPoseObservation.empty

    func test_emptyObservation_hasUnknownPoseAnd21Landmarks() {
        let empty = HandPoseObservation.empty
        XCTAssertEqual(empty.pose, .unknown)
        XCTAssertEqual(empty.confidence, 0, accuracy: 0.0001)
        XCTAssertEqual(empty.landmarks.count, 21, "21 лендмарк руки")
        XCTAssertEqual(empty.chirality, .unknown)
        XCTAssertTrue(empty.landmarks.allSatisfy { $0 == CGPoint(x: -1, y: -1) },
                      "Все точки пустого наблюдения — sentinel (-1,-1)")
    }

    func test_handChirality_rawValues() {
        XCTAssertEqual(HandChirality.left.rawValue, "left")
        XCTAssertEqual(HandChirality.right.rawValue, "right")
        XCTAssertEqual(HandChirality.unknown.rawValue, "unknown")
    }

    // MARK: - Live worker: blank frame → no hand

    func test_detect_blankFrame_returnsNil() async throws {
        let sut = HandPoseWorker()
        // Buffer создаётся и потребляется внутри одного nonisolated-региона
        // (runDetect); наружу возвращается только Sendable-результат.
        // На симуляторе Vision-контекст может быть недоступен → detect бросает;
        // оба исхода (nil или throw) — graceful, без краша.
        do {
            let result = try await Self.runDetect(sut, width: 128, height: 128)
            XCTAssertNil(result, "На кадре без руки detect возвращает nil")
        } catch {
            // Vision-контекст недоступен в тест-хосте — допустимо.
        }
    }

    func test_detect_customConfidenceThreshold_doesNotCrash() async throws {
        let sut = HandPoseWorker(maxHandCount: 1, confidenceThreshold: 0.9)
        do {
            let result = try await Self.runDetect(sut, width: 64, height: 64)
            XCTAssertNil(result)
        } catch {
            // Vision-контекст недоступен в тест-хосте — допустимо.
        }
    }

    /// Создаёт blank-кадр и сразу передаёт его актору; CVPixelBuffer не Sendable,
    /// наружу возвращается только Sendable HandPoseObservation? (region isolation).
    private static func runDetect(
        _ worker: HandPoseWorker,
        width: Int,
        height: Int
    ) async throws -> HandPoseObservation? {
        let buffer = try XCTUnwrap(makeSolidPixelBuffer(width: width, height: height))
        return try await worker.detect(in: buffer)
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
            memset(base, 90, bytes)
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
}
