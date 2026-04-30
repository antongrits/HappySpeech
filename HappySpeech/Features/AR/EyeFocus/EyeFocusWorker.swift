import ARKit
import Foundation
import OSLog
import simd

// MARK: - EyeFocusWorkerProtocol

public protocol EyeFocusWorkerProtocol: Actor {
    /// Анализирует один кадр ARFaceAnchor и возвращает observation.
    func analyze(faceAnchor: ARFaceAnchor) async -> EyeFocusObservation

    /// Вычисляет среднее внимание по переданной истории кадров.
    func computeAttention(history: [EyeFocusObservation]) async -> Float

    /// Последние накопленные наблюдения (~2 сек при 30 fps).
    func recentHistory() async -> [EyeFocusObservation]

    /// Очищает историю (при смене экрана/игры).
    func clearHistory() async
}

// MARK: - EyeFocusWorker

/// Actor, анализирующий ARFaceAnchor.lookAtPoint в режиме real-time (30 fps).
///
/// Используется ARMirrorView для определения:
/// - смотрит ли ребёнок на Лялю / в камеру;
/// - уровень внимания (attention score) для адаптации сложности;
/// - мигает ли ребёнок (пауза внимания).
///
/// Graceful fallback: на устройствах без TrueDepth камеры (iPhone SE 3)
/// ARFaceTrackingConfiguration.isSupported == false → worker не вызывается вообще.
public actor EyeFocusWorker: EyeFocusWorkerProtocol {

    // MARK: - Constants

    /// Порог по осям x/y для isLookingAtCamera (в метрах face space).
    private static let cameraThreshold: Float = 0.08

    /// Коэффициент перевода magnitude → attention (чем больше, тем резче спад).
    private static let magnitudeScale: Float = 5.0

    /// Порог blink blendshape для считывания моргания.
    private static let blinkThreshold: Float = 0.5

    /// Максимальный размер истории (~2 сек при 30 fps).
    private let maxHistory: Int

    // MARK: - State

    private var observations: [EyeFocusObservation] = []

    // MARK: - Init

    public init(maxHistory: Int = 60) {
        self.maxHistory = maxHistory
    }

    // MARK: - EyeFocusWorkerProtocol

    public func analyze(faceAnchor: ARFaceAnchor) async -> EyeFocusObservation {
        let lookAt = faceAnchor.lookAtPoint

        let leftBlink  = (faceAnchor.blendShapes[.eyeBlinkLeft]  as? Float) ?? 0.0
        let rightBlink = (faceAnchor.blendShapes[.eyeBlinkRight] as? Float) ?? 0.0

        let leftOpenness  = 1.0 - leftBlink
        let rightOpenness = 1.0 - rightBlink
        let isBlinking    = leftBlink  > Self.blinkThreshold
                         && rightBlink > Self.blinkThreshold

        let isLookingAtCamera = abs(lookAt.x) < Self.cameraThreshold
                             && abs(lookAt.y) < Self.cameraThreshold

        let magnitude = simd_length(lookAt)
        let attention = max(0.0, min(1.0, 1.0 - magnitude * Self.magnitudeScale))

        let obs = EyeFocusObservation(
            lookAtPoint:       lookAt,
            isLookingAtCamera: isLookingAtCamera,
            leftEyeOpenness:   leftOpenness,
            rightEyeOpenness:  rightOpenness,
            isBlinking:        isBlinking,
            attentionScore:    attention,
            timestamp:         Date().timeIntervalSince1970
        )

        observations.append(obs)
        if observations.count > maxHistory {
            observations.removeFirst()
        }

        return obs
    }

    public func computeAttention(history: [EyeFocusObservation]) async -> Float {
        guard !history.isEmpty else { return 0.0 }
        let sum = history.reduce(0.0) { $0 + $1.attentionScore }
        return sum / Float(history.count)
    }

    public func recentHistory() async -> [EyeFocusObservation] {
        observations
    }

    public func clearHistory() async {
        observations.removeAll()
    }
}
