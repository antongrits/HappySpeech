import Foundation
import OSLog

// MARK: - AirStreamDetector

/// Детектор направленного выдоха — комбинирует `cheekPuff` blendshape и амплитуду микрофона.
/// Используется в дыхательных AR-играх ("задуй бабочку", "сдуй одуванчик").
public final class AirStreamDetector: @unchecked Sendable {

    // MARK: Config

    public struct Config: Sendable {
        public let cheekPuffThreshold: Float       // 0…1
        public let micAmplitudeThreshold: Float    // 0…1 (нормализованный RMS)
        public let minSustainFrames: Int           // кадров подряд, чтобы сработал trigger

        public static let `default` = Config(
            cheekPuffThreshold: 0.25,
            micAmplitudeThreshold: 0.15,
            minSustainFrames: 3
        )
    }

    // MARK: State

    public private(set) var isBlowing: Bool = false
    public private(set) var strength: Float = 0
    private var sustainCounter: Int = 0
    private let config: Config

    public init(config: Config = .default) {
        self.config = config
    }

    /// Обновляет состояние детектора новым кадром.
    /// - Parameters:
    ///   - blendshapes: текущие blendshapes из ARSessionService.
    ///   - micAmplitude: нормализованная амплитуда аудио (0…1), обычно RMS из AudioService.
    /// - Returns: `true` если выдох сейчас идёт.
    @discardableResult
    public func update(blendshapes: FaceBlendshapes, micAmplitude: Float) -> Bool {
        let cheekComponent = blendshapes.cheekPuff
        let isStrongEnough = cheekComponent > config.cheekPuffThreshold
            && micAmplitude > config.micAmplitudeThreshold

        if isStrongEnough {
            sustainCounter = min(sustainCounter + 1, config.minSustainFrames * 2)
        } else {
            sustainCounter = max(sustainCounter - 1, 0)
        }

        isBlowing = sustainCounter >= config.minSustainFrames
        // Сила 0…1 — взвешенное среднее щёк и микрофона.
        strength = min(1, (cheekComponent * 0.5 + micAmplitude * 0.5))
        return isBlowing
    }

    public func reset() {
        sustainCounter = 0
        isBlowing = false
        strength = 0
    }
}
