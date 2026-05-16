@testable import HappySpeech
import AVFoundation
import XCTest

// MARK: - BreathingAudioWorkerTests
//
// Живой BreathingAudioWorker требует реального AVAudioEngine + микрофон →
// не тестируется в unit-target (нет audio hardware в симуляторе).
//
// Тестируем:
//   1. MockBreathingAudioWorker — полностью доступен
//   2. BreathingAudioWorker.computeRMS — nonisolated static, можно вызвать без hardware
//   3. BreathingAudioWorkerProtocol conformance checks через mock

// MARK: - MockBreathingAudioWorker tests

final class MockBreathingAudioWorkerTests: XCTestCase {

    // MARK: - isPermissionGranted

    func test_mockWorker_defaultPermission_isGranted() {
        let worker = MockBreathingAudioWorker()
        XCTAssertTrue(worker.isPermissionGranted, "По умолчанию permission=true")
    }

    func test_mockWorker_permissionDenied_throwsOnStart() async {
        let worker = MockBreathingAudioWorker()
        worker.isPermissionGranted = false
        do {
            try await worker.start(onAmplitude: { _ in }, onInterrupt: {})
            XCTFail("Ожидалась ошибка audioPermissionDenied")
        } catch AppError.audioPermissionDenied {
            // Ожидаемый путь
        } catch {
            XCTFail("Неожиданная ошибка: \(error)")
        }
    }

    // MARK: - requestPermission

    func test_mockWorker_requestPermission_returnsGranted() async {
        let worker = MockBreathingAudioWorker()
        let result = await worker.requestPermission()
        XCTAssertTrue(result)
    }

    func test_mockWorker_requestPermission_returnsDenied() async {
        let worker = MockBreathingAudioWorker()
        worker.isPermissionGranted = false
        let result = await worker.requestPermission()
        XCTAssertFalse(result)
    }

    // MARK: - start increments startCount

    func test_mockWorker_start_incrementsStartCount() async throws {
        let worker = MockBreathingAudioWorker()
        worker.scriptedAmplitudes = [0.5]
        try await worker.start(onAmplitude: { _ in }, onInterrupt: {})
        XCTAssertEqual(worker.startCount, 1)
    }

    func test_mockWorker_start_emptyAmplitudes_doesNotCrash() async throws {
        let worker = MockBreathingAudioWorker()
        // scriptedAmplitudes пустой → start() возвращается без запуска стрима
        try await worker.start(onAmplitude: { _ in }, onInterrupt: {})
        XCTAssertEqual(worker.startCount, 1)
    }

    // MARK: - stop increments stopCount

    func test_mockWorker_stop_incrementsStopCount() {
        let worker = MockBreathingAudioWorker()
        worker.stop()
        XCTAssertEqual(worker.stopCount, 1)
    }

    func test_mockWorker_stopTwice_stopCountIs2() {
        let worker = MockBreathingAudioWorker()
        worker.stop()
        worker.stop()
        XCTAssertEqual(worker.stopCount, 2)
    }

    // MARK: - pushSamples: synchronous amplitude delivery

    func test_mockWorker_pushSamples_deliversAllValues() {
        let worker = MockBreathingAudioWorker()
        var received: [Float] = []
        worker.pushSamples([0.1, 0.5, 0.9]) { v in received.append(v) }
        XCTAssertEqual(received, [0.1, 0.5, 0.9])
    }

    func test_mockWorker_pushSamples_empty_noCallback() {
        let worker = MockBreathingAudioWorker()
        var received: [Float] = []
        worker.pushSamples([]) { v in received.append(v) }
        XCTAssertTrue(received.isEmpty)
    }

    // MARK: - scriptedAmplitudes cycled (один тик ~100ms)

    func test_mockWorker_scriptedAmplitudes_deliveredInOrder() async throws {
        let expected: [Float] = [0.1, 0.3, 0.7]
        let worker = MockBreathingAudioWorker()
        worker.scriptedAmplitudes = expected

        let expectation = XCTestExpectation(description: "All amplitudes received")
        expectation.expectedFulfillmentCount = expected.count

        final class ReceivedBox: @unchecked Sendable {
            var values: [Float] = []
            let lock = NSLock()
        }
        let box = ReceivedBox()

        try await worker.start(
            onAmplitude: { v in
                box.lock.lock()
                box.values.append(v)
                box.lock.unlock()
                expectation.fulfill()
            },
            onInterrupt: {}
        )

        await fulfillment(of: [expectation], timeout: 1.5)
        worker.stop()

        XCTAssertEqual(
            box.values.prefix(expected.count).map { Int($0 * 10) },
            expected.map { Int($0 * 10) },
            "Амплитуды должны приходить в том же порядке"
        )
    }
}

// MARK: - BreathingAudioWorker.computeRMS tests

final class BreathingAudioWorkerComputeRMSTests: XCTestCase {

    func test_computeRMS_silenceBuffer_returnsZero() {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false
        )!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        let rms = BreathingAudioWorker.computeRMS(from: buffer)
        XCTAssertEqual(rms, 0.0, accuracy: 0.001, "Тишина → RMS=0")
    }

    func test_computeRMS_maxAmplitude_clampedToOne() {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false
        )!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<1024 { channelData[i] = 1.0 }
        }
        let rms = BreathingAudioWorker.computeRMS(from: buffer)
        XCTAssertLessThanOrEqual(rms, 1.0, "RMS должен быть ≤ 1.0 (clamped)")
        XCTAssertGreaterThan(rms, 0.0, "RMS для максимальной амплитуды > 0")
    }

    func test_computeRMS_mixedAmplitude_nonNegative() {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false
        )!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
        buffer.frameLength = 512
        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<512 { channelData[i] = i % 2 == 0 ? 0.3 : -0.3 }
        }
        let rms = BreathingAudioWorker.computeRMS(from: buffer)
        XCTAssertGreaterThanOrEqual(rms, 0.0, "RMS всегда неотрицательный")
    }

    func test_computeRMS_emptyBuffer_returnsZero() {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false
        )!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 0
        let rms = BreathingAudioWorker.computeRMS(from: buffer)
        XCTAssertEqual(rms, 0.0, "Пустой буфер (frameLength=0) → RMS=0")
    }
}
