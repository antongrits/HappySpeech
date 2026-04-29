import ARKit
import OSLog

// MARK: - BodyPoseUpdate

/// Снимок текущего положения суставов тела, полученный из ARBodyAnchor.
public struct BodyPoseUpdate: Sendable {
    /// Позиции суставов в системе координат модели (modelTransform).
    public let joints: [ARSkeleton.JointName: SIMD3<Float>]
    /// Уверенность трекинга: 1.0 — якорь уверенно отслеживается, 0.0 — потерян.
    public let confidence: Float
}

// MARK: - BodyPoseWorker

/// Worker для real-time body pose tracking через ARBodyTrackingConfiguration.
/// Требует A12+ (iPhone XS / XR и новее). На неподдерживаемых устройствах
/// `isAvailable == false` — вместо ARKit генерирует mock-обновления (~10fps).
///
/// Жизненный цикл: `start()` → получай обновления через `onUpdate` → `stop()`.
/// Все колбэки `onUpdate` вызываются на `@MainActor`.
@MainActor
public final class BodyPoseWorker: NSObject {

    // MARK: - Public API

    /// Устройство поддерживает `ARBodyTrackingConfiguration`.
    public private(set) var isAvailable: Bool

    /// Колбэк на каждый кадр с обновлёнными суставами.
    public var onUpdate: ((BodyPoseUpdate) -> Void)?

    // MARK: - Private

    private let arSession = ARSession()
    private var mockTask: Task<Void, Never>?
    private var mockPhase: Float = 0

    // MARK: - Init

    public override init() {
        self.isAvailable = ARBodyTrackingConfiguration.isSupported
        super.init()
        arSession.delegate = self
    }

    // MARK: - Lifecycle

    /// Запускает body tracking.
    /// Если `isAvailable == false` — стартует mock, чтобы interactor мог работать на симуляторе.
    public func start() {
        if isAvailable {
            startARSession()
        } else {
            startMock()
        }
    }

    /// Останавливает tracking и освобождает ресурсы.
    public func stop() {
        if isAvailable {
            arSession.pause()
        } else {
            mockTask?.cancel()
            mockTask = nil
        }
        HSLogger.ar.info("BodyPoseWorker stopped (available=\(self.isAvailable))")
    }

    // MARK: - Private helpers

    private func startARSession() {
        let config = ARBodyTrackingConfiguration()
        config.automaticSkeletonScaleEstimationEnabled = true
        arSession.run(config, options: [.resetTracking, .removeExistingAnchors])
        HSLogger.ar.info("BodyPoseWorker ARBodyTrackingConfiguration started")
    }

    private func startMock() {
        HSLogger.ar.warning("ARBodyTrackingConfiguration not supported — BodyPoseWorker using mock")
        mockTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                self.mockPhase += 0.12
                let wave = (sin(self.mockPhase) + 1) / 2
                let joints = Self.mockJoints(wave: wave)
                self.onUpdate?(BodyPoseUpdate(joints: joints, confidence: 0.85))
                try? await Task.sleep(nanoseconds: 100_000_000) // ~10fps
            }
        }
    }

    /// Генерирует анимированные mock-позиции суставов для тестирования на симуляторе.
    private static func mockJoints(wave: Float) -> [ARSkeleton.JointName: SIMD3<Float>] {
        [
            .root:          SIMD3(0, 0, 0),
            .head:          SIMD3(0, 1.7, 0),
            .leftShoulder:  SIMD3(-0.2, 1.4, 0),
            .rightShoulder: SIMD3(0.2, 1.4, 0),
            .leftHand:      SIMD3(-0.5 - wave * 0.2, 1.0 + wave * 0.3, 0),
            .rightHand:     SIMD3(0.5 + wave * 0.2, 1.0 + wave * 0.3, 0),
            .leftFoot:      SIMD3(-0.15, 0, 0),
            .rightFoot:     SIMD3(0.15, 0, 0)
        ]
    }
}

// MARK: - ARSessionDelegate

extension BodyPoseWorker: ARSessionDelegate {

    public nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let bodyAnchors = anchors.compactMap { $0 as? ARBodyAnchor }
        guard let body = bodyAnchors.first else { return }

        let skeleton = body.skeleton
        let trackedJoints: [ARSkeleton.JointName] = [
            .root, .head,
            .leftHand, .rightHand,
            .leftFoot, .rightFoot,
            .leftShoulder, .rightShoulder
        ]

        var joints: [ARSkeleton.JointName: SIMD3<Float>] = [:]
        for joint in trackedJoints {
            if let transform = skeleton.modelTransform(for: joint) {
                joints[joint] = SIMD3<Float>(
                    transform.columns.3.x,
                    transform.columns.3.y,
                    transform.columns.3.z
                )
            }
        }

        // ARBodyAnchor.isTracked — признак уверенности трекинга (iOS 16+).
        let confidence: Float = body.isTracked ? 1.0 : 0.0

        let update = BodyPoseUpdate(joints: joints, confidence: confidence)
        Task { @MainActor [weak self] in
            self?.onUpdate?(update)
        }
    }

    public nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        HSLogger.ar.error("BodyPoseWorker ARSession error: \(error.localizedDescription)")
    }
}
