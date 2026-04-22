import ARKit
import AVFoundation
import Combine
import Foundation
import OSLog
#if canImport(RealityKit)
import RealityKit
#endif

// MARK: - FaceBlendshapes

/// Snapshot of the currently-tracked face blendshape values. Values are in `0...1`.
/// Built from `ARFaceAnchor.blendShapes`. Used by AR games and `TonguePostureClassifier`.
public struct FaceBlendshapes: Sendable, Equatable {

    // MARK: Jaw
    public let jawOpen: Float
    public let jawForward: Float

    // MARK: Mouth shape
    public let mouthFunnel: Float      // "хоботок"
    public let mouthPucker: Float      // "трубочка"
    public let mouthSmileLeft: Float
    public let mouthSmileRight: Float
    public let mouthFrownLeft: Float
    public let mouthFrownRight: Float
    public let mouthRollLower: Float
    public let mouthRollUpper: Float
    public let mouthStretchLeft: Float
    public let mouthStretchRight: Float
    public let mouthLowerDownLeft: Float
    public let mouthLowerDownRight: Float
    public let mouthUpperUpLeft: Float
    public let mouthUpperUpRight: Float
    public let mouthClose: Float
    public let mouthLeft: Float
    public let mouthRight: Float

    // MARK: Tongue
    public let tongueOut: Float        // 0…1 — выдвинутость языка

    // MARK: Eyes (fatigue hints)
    public let eyeBlinkLeft: Float
    public let eyeBlinkRight: Float

    // MARK: Cheeks
    public let cheekPuff: Float        // надутые щёки (полезно для дыхательных игр)

    // MARK: - Computed

    /// Синоним `jawOpen`.
    public var mouthOpenness: Float { jawOpen }

    /// Симметрия растяжения губ влево/вправо. 1.0 — идеально симметрично.
    public var lipSymmetry: Float {
        let leftSpread = (mouthSmileLeft + mouthStretchLeft) / 2
        let rightSpread = (mouthSmileRight + mouthStretchRight) / 2
        let maxSide = max(leftSpread, rightSpread)
        guard maxSide > 0.01 else { return 1 }
        let minSide = min(leftSpread, rightSpread)
        return minSide / maxSide
    }

    /// Ребёнок улыбается.
    public var isSmiling: Bool { mouthSmileLeft > 0.3 && mouthSmileRight > 0.3 }

    /// Язык высунут.
    public var isTongueOut: Bool { tongueOut > 0.5 }

    /// Среднее моргание (0…1).
    public var averageBlink: Float { (eyeBlinkLeft + eyeBlinkRight) / 2 }

    // MARK: - Init from ARFaceAnchor

    public init(from anchor: ARFaceAnchor) {
        let b = anchor.blendShapes
        self.jawOpen             = b[.jawOpen]?.floatValue ?? 0
        self.jawForward          = b[.jawForward]?.floatValue ?? 0
        self.mouthFunnel         = b[.mouthFunnel]?.floatValue ?? 0
        self.mouthPucker         = b[.mouthPucker]?.floatValue ?? 0
        self.mouthSmileLeft      = b[.mouthSmileLeft]?.floatValue ?? 0
        self.mouthSmileRight     = b[.mouthSmileRight]?.floatValue ?? 0
        self.mouthFrownLeft      = b[.mouthFrownLeft]?.floatValue ?? 0
        self.mouthFrownRight     = b[.mouthFrownRight]?.floatValue ?? 0
        self.mouthRollLower      = b[.mouthRollLower]?.floatValue ?? 0
        self.mouthRollUpper      = b[.mouthRollUpper]?.floatValue ?? 0
        self.mouthStretchLeft    = b[.mouthStretchLeft]?.floatValue ?? 0
        self.mouthStretchRight   = b[.mouthStretchRight]?.floatValue ?? 0
        self.mouthLowerDownLeft  = b[.mouthLowerDownLeft]?.floatValue ?? 0
        self.mouthLowerDownRight = b[.mouthLowerDownRight]?.floatValue ?? 0
        self.mouthUpperUpLeft    = b[.mouthUpperUpLeft]?.floatValue ?? 0
        self.mouthUpperUpRight   = b[.mouthUpperUpRight]?.floatValue ?? 0
        self.mouthClose          = b[.mouthClose]?.floatValue ?? 0
        self.mouthLeft           = b[.mouthLeft]?.floatValue ?? 0
        self.mouthRight          = b[.mouthRight]?.floatValue ?? 0
        self.tongueOut           = b[.tongueOut]?.floatValue ?? 0
        self.eyeBlinkLeft        = b[.eyeBlinkLeft]?.floatValue ?? 0
        self.eyeBlinkRight       = b[.eyeBlinkRight]?.floatValue ?? 0
        self.cheekPuff           = b[.cheekPuff]?.floatValue ?? 0
    }

    /// Memberwise init — используется mock-реализацией и тестами.
    public init(
        jawOpen: Float = 0,
        jawForward: Float = 0,
        mouthFunnel: Float = 0,
        mouthPucker: Float = 0,
        mouthSmileLeft: Float = 0,
        mouthSmileRight: Float = 0,
        mouthFrownLeft: Float = 0,
        mouthFrownRight: Float = 0,
        mouthRollLower: Float = 0,
        mouthRollUpper: Float = 0,
        mouthStretchLeft: Float = 0,
        mouthStretchRight: Float = 0,
        mouthLowerDownLeft: Float = 0,
        mouthLowerDownRight: Float = 0,
        mouthUpperUpLeft: Float = 0,
        mouthUpperUpRight: Float = 0,
        mouthClose: Float = 0,
        mouthLeft: Float = 0,
        mouthRight: Float = 0,
        tongueOut: Float = 0,
        eyeBlinkLeft: Float = 0,
        eyeBlinkRight: Float = 0,
        cheekPuff: Float = 0
    ) {
        self.jawOpen = jawOpen
        self.jawForward = jawForward
        self.mouthFunnel = mouthFunnel
        self.mouthPucker = mouthPucker
        self.mouthSmileLeft = mouthSmileLeft
        self.mouthSmileRight = mouthSmileRight
        self.mouthFrownLeft = mouthFrownLeft
        self.mouthFrownRight = mouthFrownRight
        self.mouthRollLower = mouthRollLower
        self.mouthRollUpper = mouthRollUpper
        self.mouthStretchLeft = mouthStretchLeft
        self.mouthStretchRight = mouthStretchRight
        self.mouthLowerDownLeft = mouthLowerDownLeft
        self.mouthLowerDownRight = mouthLowerDownRight
        self.mouthUpperUpLeft = mouthUpperUpLeft
        self.mouthUpperUpRight = mouthUpperUpRight
        self.mouthClose = mouthClose
        self.mouthLeft = mouthLeft
        self.mouthRight = mouthRight
        self.tongueOut = tongueOut
        self.eyeBlinkLeft = eyeBlinkLeft
        self.eyeBlinkRight = eyeBlinkRight
        self.cheekPuff = cheekPuff
    }

    /// Нейтральная поза — все значения нулевые.
    public static let neutral = FaceBlendshapes()

    /// Удобная демо-поза улыбки для превью.
    public static let smile = FaceBlendshapes(
        mouthSmileLeft: 0.7,
        mouthSmileRight: 0.7
    )

    /// Удобная демо-поза «хоботок».
    public static let funnel = FaceBlendshapes(mouthFunnel: 0.8)
}

// MARK: - ARSessionError

public enum ARSessionError: Error, LocalizedError, Sendable {
    case notSupported
    case cameraPermissionDenied
    case sessionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notSupported:
            return String(localized: "ar.error.notSupported")
        case .cameraPermissionDenied:
            return String(localized: "ar.error.cameraPermissionDenied")
        case .sessionFailed(let message):
            return message
        }
    }
}

// MARK: - ARSessionService Protocol

/// Central AR face-tracking service. Wraps ARKit session lifecycle and exposes blendshape frames
/// as an `AsyncStream` so VIP Interactors consume frames without touching ARKit directly.
@MainActor
public protocol ARSessionService: AnyObject {

    /// Устройство поддерживает `ARFaceTrackingConfiguration`.
    var isSupported: Bool { get }

    /// Сессия запущена.
    var isRunning: Bool { get }

    /// Последний снятый кадр blendshapes (удобно для разовых запросов).
    var currentBlendshapes: FaceBlendshapes? { get }

    /// Подписка на кадры (около 30fps).
    var blendshapeStream: AsyncStream<FaceBlendshapes> { get }

    /// Ссылка на underlying `ARSession` — нужна `ARView` / `ARSCNView` чтобы рендерить.
    /// Может быть `nil` у mock-реализации.
    var underlyingSession: ARSession? { get }

    /// Старт face-tracking. Бросает `ARSessionError` если AR не поддерживается или нет доступа.
    func startSession() async throws

    func stopSession()

    func pauseSession()

    func resumeSession() async throws
}

// MARK: - LiveARSessionService

/// Live implementation backed by `ARKit.ARSession` + `ARFaceTrackingConfiguration`.
/// `@unchecked Sendable` because `ARSession` is not `Sendable`; all mutations happen on `MainActor`.
@MainActor
public final class LiveARSessionService: NSObject, ARSessionService, @unchecked Sendable {

    // MARK: Published state

    public private(set) var isRunning: Bool = false
    public private(set) var currentBlendshapes: FaceBlendshapes?

    public var isSupported: Bool { ARFaceTrackingConfiguration.isSupported }

    public var underlyingSession: ARSession? { session }

    // MARK: Stream

    public let blendshapeStream: AsyncStream<FaceBlendshapes>
    private let continuation: AsyncStream<FaceBlendshapes>.Continuation

    // MARK: ARKit

    private let session = ARSession()

    // MARK: - Init

    public override init() {
        var capturedContinuation: AsyncStream<FaceBlendshapes>.Continuation!
        self.blendshapeStream = AsyncStream { continuation in
            capturedContinuation = continuation
        }
        self.continuation = capturedContinuation
        super.init()
        self.session.delegate = self
        HSLogger.ar.debug("LiveARSessionService initialised (supported=\(self.isSupported))")
    }

    deinit {
        continuation.finish()
    }

    // MARK: - Lifecycle

    public func startSession() async throws {
        guard isSupported else {
            HSLogger.ar.error("AR face tracking not supported on this device")
            throw ARSessionError.notSupported
        }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else { throw ARSessionError.cameraPermissionDenied }
        } else if status != .authorized {
            throw ARSessionError.cameraPermissionDenied
        }

        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        config.maximumNumberOfTrackedFaces = 1
        if ARFaceTrackingConfiguration.supportsWorldTracking {
            config.isWorldTrackingEnabled = false
        }
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        isRunning = true
        HSLogger.ar.info("AR session started")
    }

    public func stopSession() {
        session.pause()
        isRunning = false
        currentBlendshapes = nil
        HSLogger.ar.info("AR session stopped")
    }

    public func pauseSession() {
        session.pause()
        isRunning = false
        HSLogger.ar.debug("AR session paused")
    }

    public func resumeSession() async throws {
        try await startSession()
    }
}

// MARK: - ARSessionDelegate

extension LiveARSessionService: ARSessionDelegate {

    public nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor else { return }
        let snapshot = FaceBlendshapes(from: faceAnchor)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.currentBlendshapes = snapshot
            self.continuation.yield(snapshot)
        }
    }

    public nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        HSLogger.ar.error("ARSession failed: \(error.localizedDescription)")
        Task { @MainActor [weak self] in
            self?.isRunning = false
        }
    }

    public nonisolated func sessionWasInterrupted(_ session: ARSession) {
        HSLogger.ar.debug("ARSession interrupted")
        Task { @MainActor [weak self] in
            self?.isRunning = false
        }
    }

    public nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        HSLogger.ar.debug("ARSession interruption ended")
    }
}

// MARK: - MockARSessionService

/// Mock service for SwiftUI previews and tests. Emits animated random blendshapes at ~15fps.
@MainActor
public final class MockARSessionService: ARSessionService, @unchecked Sendable {

    public var isSupported: Bool = true
    public private(set) var isRunning: Bool = false
    public private(set) var currentBlendshapes: FaceBlendshapes?

    public var underlyingSession: ARSession? { nil }

    public let blendshapeStream: AsyncStream<FaceBlendshapes>
    private let continuation: AsyncStream<FaceBlendshapes>.Continuation

    private var tickTask: Task<Void, Never>?
    private var phase: Float = 0

    public init(isSupported: Bool = true) {
        self.isSupported = isSupported
        var capturedContinuation: AsyncStream<FaceBlendshapes>.Continuation!
        self.blendshapeStream = AsyncStream { continuation in
            capturedContinuation = continuation
        }
        self.continuation = capturedContinuation
    }

    deinit {
        tickTask?.cancel()
        continuation.finish()
    }

    public func startSession() async throws {
        guard isSupported else { throw ARSessionError.notSupported }
        guard !isRunning else { return }
        isRunning = true
        tickTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled, self.isRunning {
                self.phase += 0.1
                let wave = (sin(self.phase) + 1) / 2  // 0…1
                let snapshot = FaceBlendshapes(
                    jawOpen: wave * 0.5,
                    mouthFunnel: max(0, sin(self.phase * 0.7)) * 0.6,
                    mouthSmileLeft: max(0, cos(self.phase * 0.5)) * 0.5,
                    mouthSmileRight: max(0, cos(self.phase * 0.5)) * 0.5,
                    tongueOut: max(0, sin(self.phase * 0.3)) * 0.4,
                    cheekPuff: max(0, sin(self.phase * 0.4)) * 0.3
                )
                self.currentBlendshapes = snapshot
                self.continuation.yield(snapshot)
                try? await Task.sleep(nanoseconds: 66_000_000)  // ~15fps
            }
        }
    }

    public func stopSession() {
        tickTask?.cancel()
        tickTask = nil
        isRunning = false
        currentBlendshapes = nil
    }

    public func pauseSession() {
        tickTask?.cancel()
        tickTask = nil
        isRunning = false
    }

    public func resumeSession() async throws {
        try await startSession()
    }
}
