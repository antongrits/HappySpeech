import Foundation
import simd

// MARK: - EyeFocusObservation

/// Снимок данных взгляда из одного кадра ARFaceAnchor.
/// Все вычисления происходят в системе координат лица (face coordinate space).
public struct EyeFocusObservation: Sendable {

    /// Точка взгляда в локальных координатах лица.
    /// Источник: ARFaceAnchor.lookAtPoint (SIMD3<Float>).
    public let lookAtPoint: SIMD3<Float>

    /// true = ребёнок смотрит примерно в камеру/экран.
    /// Порог: |x| < 0.08 && |y| < 0.08 (метры в face space).
    public let isLookingAtCamera: Bool

    /// Открытость левого глаза 0...1 (1 = полностью открыт, 0 = закрыт).
    /// Вычислено как 1 - blendShapes[.eyeBlinkLeft].
    public let leftEyeOpenness: Float

    /// Открытость правого глаза 0...1.
    public let rightEyeOpenness: Float

    /// true = оба глаза закрыты (оба blink > 0.5). Ребёнок моргает.
    public let isBlinking: Bool

    /// Оценка внимания 0...1. 1.0 = смотрит прямо в камеру, 0.0 = смотрит далеко.
    /// Формула: max(0, min(1, 1 - magnitude(lookAtPoint) * 5)).
    public let attentionScore: Float

    /// Метка времени создания наблюдения (seconds since 1970).
    public let timestamp: TimeInterval
}

// MARK: - EyeFocusStatus

/// Статус eye tracking — используется UI для выбора режима отображения.
public enum EyeFocusStatus: Sendable {
    /// TrueDepth камера не поддерживается (iPhone SE 3 и другие без Face ID).
    case unsupported
    /// AR сессия ещё не запущена или лицо не обнаружено.
    case idle
    /// Активное отслеживание взгляда.
    case tracking(EyeFocusObservation)
}
