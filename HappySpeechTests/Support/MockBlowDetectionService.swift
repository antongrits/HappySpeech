import Foundation
@testable import HappySpeech

// MARK: - MockBlowDetectionService
//
// Тестовый/Preview-дубль `BlowDetecting`. Отдаёт заранее заданную ленту кадров
// в `liveStream` и фиксированный `fileResult` из `analyzeFile`. Без аудиостека.

public final class MockBlowDetectionService: BlowDetecting, @unchecked Sendable {

    /// Кадры, которые будут отданы в `liveStream` после `startLive()`.
    public var scriptedSamples: [BlowSample] = []
    /// Результат, возвращаемый `analyzeFile`.
    public var fileResult: BlowFileResult = BlowFileResult(samples: [])
    /// Управляет успехом `startLive()` (false → имитирует отсутствие микрофона).
    public var startSucceeds: Bool = true

    public private(set) var startLiveCallCount = 0
    public private(set) var stopLiveCallCount = 0

    private let lock = NSLock()
    private var continuation: AsyncStream<BlowSample>.Continuation?

    public init() {}

    public var liveStream: AsyncStream<BlowSample> {
        AsyncStream { continuation in
            lock.lock()
            self.continuation = continuation
            let scripted = self.scriptedSamples
            lock.unlock()
            for sample in scripted { continuation.yield(sample) }
        }
    }

    @discardableResult
    public func startLive() async -> Bool {
        startLiveCallCount += 1
        return startSucceeds
    }

    public func stopLive() async {
        stopLiveCallCount += 1
        lock.withLock {
            continuation?.finish()
            continuation = nil
        }
    }

    public func analyzeFile(url: URL) async throws -> BlowFileResult {
        fileResult
    }
}
