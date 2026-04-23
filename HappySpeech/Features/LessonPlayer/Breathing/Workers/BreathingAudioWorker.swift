import Foundation
import AVFoundation
import Accelerate
import OSLog

// MARK: - BreathingAudioWorkerProtocol

protocol BreathingAudioWorkerProtocol: AnyObject, Sendable {
    /// Microphone permission. Returns `true` if granted.
    func requestPermission() async -> Bool
    var isPermissionGranted: Bool { get }

    /// Install a mic tap and start feeding RMS samples back.
    func start(onAmplitude: @escaping @Sendable (Float) -> Void,
               onInterrupt: @escaping @Sendable () -> Void) async throws

    /// Stop the mic tap.
    func stop()
}

// MARK: - BreathingAudioWorker (live)
//
// Wraps an `AVAudioEngine` to sample 1024-frame buffers, compute RMS with
// vDSP, and forward 50 ms windows to the interactor. The worker owns the
// engine so the game has an isolated audio session that cannot be perturbed
// by other features (TTS, sound chips, etc.).
//
// The class is `@unchecked Sendable` because AVAudioEngine itself is a
// Foundation class without formal Sendable conformance, but we always
// mutate the engine from the main thread via async calls; the tap closure
// only reads immutable locals and forwards RMS through the supplied
// `@Sendable` callback.

public final class BreathingAudioWorker: BreathingAudioWorkerProtocol, @unchecked Sendable {

    // MARK: Dependencies

    nonisolated(unsafe) private let engine: AVAudioEngine
    private let session: AVAudioSession

    // MARK: State

    nonisolated(unsafe) private var isTapInstalled: Bool = false
    nonisolated(unsafe) private var interruptionObserver: NSObjectProtocol?
    private let lock = NSRecursiveLock()

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    // MARK: Init

    public init(
        engine: AVAudioEngine = AVAudioEngine(),
        session: AVAudioSession = .sharedInstance()
    ) {
        self.engine = engine
        self.session = session
    }

    deinit {
        if let token = interruptionObserver {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: Permission

    public var isPermissionGranted: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    public func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    // MARK: Engine lifecycle

    public func start(
        onAmplitude: @escaping @Sendable (Float) -> Void,
        onInterrupt: @escaping @Sendable () -> Void
    ) async throws {
        guard isPermissionGranted else {
            throw AppError.audioPermissionDenied
        }

        try configureSession()
        observeInterruptions(onInterrupt: onInterrupt)

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        let wasInstalled = withLock { isTapInstalled }
        if wasInstalled {
            inputNode.removeTap(onBus: 0)
        }

        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: format
        ) { buffer, _ in
            let amplitude = Self.computeRMS(from: buffer)
            onAmplitude(amplitude)
        }
        withLock { isTapInstalled = true }

        engine.prepare()
        try engine.start()
        HSLogger.audio.info("Breathing audio worker: engine started")
    }

    public func stop() {
        let wasInstalled: Bool = withLock {
            let prev = isTapInstalled
            isTapInstalled = false
            return prev
        }
        if wasInstalled {
            engine.inputNode.removeTap(onBus: 0)
        }
        if engine.isRunning {
            engine.stop()
        }
        if let token = interruptionObserver {
            NotificationCenter.default.removeObserver(token)
            interruptionObserver = nil
        }
        HSLogger.audio.info("Breathing audio worker: engine stopped")
    }

    // MARK: - Helpers

    private func configureSession() throws {
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func observeInterruptions(onInterrupt: @escaping @Sendable () -> Void) {
        if let token = interruptionObserver {
            NotificationCenter.default.removeObserver(token)
        }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { notification in
            guard let info = notification.userInfo,
                  let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else {
                return
            }
            if type == .began {
                onInterrupt()
            }
        }
    }

    /// Computes the RMS of a mono float32 buffer using vDSP.
    /// Returns a normalised amplitude in the 0…1 range (clamped).
    nonisolated static func computeRMS(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return 0 }

        let samples = channelData[0]
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(frameCount))

        // RMS is in the 0…1 range for float32 normalised PCM but practical
        // speech peaks max out around 0.3–0.5. Multiply to spread across the
        // full 0…1 range we care about in the game.
        return min(1, rms * 3.0)
    }
}

// MARK: - Mock worker (for Previews and unit tests)

public final class MockBreathingAudioWorker: BreathingAudioWorkerProtocol, @unchecked Sendable {

    public var isPermissionGranted: Bool = true
    public var scriptedAmplitudes: [Float] = []
    public private(set) var startCount: Int = 0
    public private(set) var stopCount: Int = 0

    private var timer: Timer?
    private var cursor: Int = 0

    public init() {}

    public func requestPermission() async -> Bool { isPermissionGranted }

    public func start(
        onAmplitude: @escaping @Sendable (Float) -> Void,
        onInterrupt: @escaping @Sendable () -> Void
    ) async throws {
        startCount += 1
        if !isPermissionGranted {
            throw AppError.audioPermissionDenied
        }
        guard !scriptedAmplitudes.isEmpty else { return }
        cursor = 0
        await MainActor.run {
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self else { return }
                let value = self.scriptedAmplitudes[self.cursor % self.scriptedAmplitudes.count]
                self.cursor += 1
                onAmplitude(value)
            }
        }
    }

    public func stop() {
        stopCount += 1
        timer?.invalidate()
        timer = nil
    }

    /// Synchronously push `count` amplitude samples. Useful for
    /// deterministic unit tests where real timers would be flaky.
    public func pushSamples(_ values: [Float], onAmplitude: (Float) -> Void) {
        for value in values { onAmplitude(value) }
    }
}
