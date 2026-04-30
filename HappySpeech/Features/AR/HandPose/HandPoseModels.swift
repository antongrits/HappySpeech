import CoreGraphics
import Foundation

// MARK: - HandPose

/// Распознанная поза руки, классифицированная по эвристике из 21 лендмарка Vision.
public enum HandPose: String, Sendable, CaseIterable, Equatable {
    case openPalm   = "open_palm"
    case fist       = "fist"
    case point      = "point"
    case pinch      = "pinch"
    case wave       = "wave"
    case thumbsUp   = "thumbs_up"
    case unknown    = "unknown"

    /// Человекочитаемое название для логов (не для UI — UI использует String Catalog).
    var debugDescription: String {
        switch self {
        case .openPalm:  return "открытая ладонь"
        case .fist:      return "кулак"
        case .point:     return "указательный"
        case .pinch:     return "щепотка"
        case .wave:      return "волна"
        case .thumbsUp:  return "большой вверх"
        case .unknown:   return "неизвестно"
        }
    }
}

// MARK: - HandChirality

/// Определяет какая рука: левая, правая или неопределённая.
public enum HandChirality: String, Sendable {
    case left
    case right
    case unknown
}

// MARK: - HandPoseObservation

/// Снимок одного кадра: результат работы `HandPoseWorker` над одним `CVPixelBuffer`.
public struct HandPoseObservation: Sendable {
    /// Классифицированная поза.
    public let pose: HandPose
    /// Средняя уверенность ключевых точек, [0…1].
    public let confidence: Float
    /// Нормализованные координаты 21 лендмарка (порядок: VNHumanHandPoseObservation.JointName.allCases).
    /// Если точка не детектирована — CGPoint(x: -1, y: -1).
    public let landmarks: [CGPoint]
    /// Лево/право.
    public let chirality: HandChirality
    /// Метка времени (секунды с 1970).
    public let timestamp: TimeInterval

    /// Создаёт "пустое" наблюдение для состояния ожидания.
    public static let empty = HandPoseObservation(
        pose: .unknown,
        confidence: 0,
        landmarks: Array(repeating: CGPoint(x: -1, y: -1), count: 21),
        chirality: .unknown,
        timestamp: 0
    )
}
